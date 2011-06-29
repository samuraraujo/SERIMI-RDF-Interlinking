#Serimi Functionalities.
#Author: Samur Araujo
#Date: 10 April 2011.
#License: SERIMI is distributed under the LGPL[http://www.gnu.org/licenses/lgpl.html] license. 
require './active_rdf/lib/active_rdf'
require './activerdf_sparql-1.3.6/lib/activerdf_sparql/init'
require 'active_support/inflector'

$label=["?p"]
module Serimi_Module
  $session = Hash.new
   
  def initialize(params)

    $output=params[:output]
    $format=params[:format]
    $filter_threshold=params[:stringthreshold]
    $rdsthreshold=params[:rdsthreshold]
  
    $removelabels=[]
      
    
    $t1=Time.now
    count = 0
    manual_offset=params[:offset]

    origin_endpoint=params[:source]

    target_endpoint=params[:target]

    $session[:source] = mount_adapter(origin_endpoint,:post,false)
    $session[:target] = mount_adapter(target_endpoint,:post,false)
    

    classes = Query.new.adapters($session[:source]).sparql("select distinct ?o where {?s a ?o}").execute
    limit = params[:chunk]

    $textp = nil

    classes = [ "<"+ params[:class] + ">"]

    start = true
    delete = true
    # $lastclass=nil
    classes.each{|s|

      puts " LAST CLASS"
      puts $lastclass
      $pivot = []
      $pivot_labels = []
      $pivot_subjects = []
      if $lastclass != nil && start
      next if s != $lastclass
      start = false
      end

      klass = s
      $lastclass= klass
      labels =  get_entity_labels(klass)

      count =  Query.new.adapters($session[:source]).sparql("select distinct count(?s) where {?s ?p #{klass} .}").execute[0][0].to_i
      offset = 0
      puts  "PREVIOUS OFFSET"
      puts $offset

      # manual_offset= count - 50
      # manual_offset=3240

      $offset=manual_offset if manual_offset >0
      offset = $offset.to_i  if $offset != nil

      puts "STARTING FROM OFFSET " + offset.to_s
      puts "NUMBER OF INSTANCES"
      puts count

        get_first_pivot(klass,5, offset, labels)
      while offset <= count    do
        puts "OFFSET"
        $offset=offset
        puts offset
        puts "LIMIT"
        puts limit

        RDFS::Resource.reset_cache()
        $ifp=nil

        resources  = get_ambiguous(klass,limit, offset, labels)

        offset=offset+limit
        subjects = resources[0]
        data = resources[1]

        if data.size == 1 and offset < count and limit < 100

          offset=offset-limit
          limit = limit + limit
          puts "CHANGING LIMIT TO " + limit.to_s
        next
        end
        next if data.size == 1 or data.size == 0

        $subjects=subjects.map{|x| x[0].label}
        web_build_sample(data,subjects)
      # break if offset > 60
      # break
      end
      puts "LAST OFFSET PROCESSED"
      puts $offset
      puts limit
      $offset =nil
      $lastclass=nil
    }

    puts $t2=Time.now

    starttime_sec= $t1.strftime("%S").to_i
    starttime_min= $t1.strftime("%M").to_i
    endtime_sec= $t2.strftime("%S").to_i
    endtime_min= $t2.strftime("%M").to_i
    diff_sec= endtime_sec - starttime_sec
    diff_sec1= diff_sec.to_s
    diff_min= endtime_min - starttime_min
    diff_min1= diff_min.to_s
    puts "\nElapsed time:\n "+ "Min-> " +diff_min1 + " Sec-> "+ diff_sec1
    puts $t2-$t1
    puts "NUMBER OF INSTANCES PROCESSED"
    puts count
    $logger.fsync if $logger!=nil

  end
 ##############################################################################################################################
  def get_first_pivot(klass,limit, offset, labels)
    puts "Obtaining First Pivot"
    resources  = get_ambiguous(klass,limit, offset, labels)

    subjects = resources[0]
    data = resources[1]
    return if data.size == 1 or data.size == 0

    $subjects=subjects.map{|x| x[0].label}
    $origin_subjects =  subjects.map{|s|
      begin
        Query.new.adapters($session[:source]).sparql("select distinct ?p ?o where { #{s} ?p ?o. }").execute
      rescue Exception => e
        e.message
        Query.new.adapters($session[:source]).sparql("select distinct ?p ?o where { #{s} ?p ?o. }").execute
      end
    }
    rdf2svm_with_meta_properties(data , [])

    puts "End of Obtaining First Pivot"
  end

  ##############################################################################################################################
  def entity_label_filtering(rdfdata)
    puts "Filtering Data by Entity Label"
    discriminative_predicates=[]
    result_entropy = entropy_computation(rdfdata)
    discriminative_predicates = result_entropy[0]
    entropies = result_entropy[1]
    puts "ENTITY LABELS FOR FILTERING"
    puts discriminative_predicates
    puts "################################"

    ######################## SELECTING RESOURCE WITH MAXIMUM STRING SIMILARITY MEASURE PER GROUP ##########################
    count=-1
    rdfdata.each{|group|
      count=count+1
      next if group.size == 0
      # puts "Selecting Maximum String Similarity Resources"
      # puts "SELECTING RESOURCES"
      # puts group.size
      # puts group.map{|s,p| s}.uniq
      max = 0
      maximas = group.map{|s,p,o|
        entitylabel = discriminative_predicates.include?(p)
        entitylabel= true if discriminative_predicates.size == 0 # not enough information was used to compute the entropy
        entitylabel = true if (o.to_i != 0)

        # puts "@@@@@"
        # puts p
        # puts (entropies[p])
        # puts "@@@@@"
        [s,p,o, (o.instance_of?(RDFS::Resource) or $textp.include?(p) or !entitylabel) ? 0 : (max_jaro(o.to_s, @searchedlabels[count],s).to_f ) , entropies[p] == nil ? 0 : 1-entropies[p]]   }
      # maximas = group.map{|s,p,o|  [s,p,o, (o.instance_of?(RDFS::Resource) or $textp.include?(p)  ) ? 0 : max_jaro(o.to_s, @searchedlabels[count],s).to_f ]   }
      max = maximas.map{|s,p,o,m| m }.max

      # puts  "MAXIMA"
      # puts max
      selection = []
      selection = maximas.map{|s,p,o,m,e| s if m == max  }.uniq.compact if max > $filter_threshold
      # maximas = maximas.map{|s,p,o,m,e| [s,p,o,m,e] if m == max  }.uniq.compact if max > $filter_threshold
      # max_entropy = maximas.map{|s,p,o,m,e| e }.max
      # selection = maximas.map {|s,p,o,m,e| s if   e == max_entropy}.uniq.compact  if max > $filter_threshold
      # # puts maximas.map{|s,p,o,m| [s,o] if  m == max}.uniq
      # # puts selection
      group.delete_if{|s,p,o|  !selection.include?(s)}.compact
    # puts "AFTER SELECTION"
    # puts group.map{|s,p| s}.uniq
    }
  end

  #############################################################################################
  def max_jaro (a,labels,s)
    # puts "COMPUTING MAX JARO ... "
    # puts s
    c = 0
    # puts "LABELS"
    # puts labels
    a =a.downcase
    labels.each{|x|
      c = c + a.jarowinkler_similar(x.downcase)
    }
    # puts labels
    # puts a
    # puts c
    c
  end

  ## GET ENTITY LABELS
  def get_entity_labels(klass)
    puts "get_entity_labels"
    data = Query.new.adapters($session[:source]).sparql("select distinct ?s ?x ?o where {?s ?x ?o . ?s ?p #{klass} .}   limit #{2000} ").execute
    $textp = get_text_properties([data])
    data.map! {|s,p,o| [s,p,o] if !$textp.include?(p) }.compact.uniq
    labels = []
    candidates = entropy_computation([data])[0]
    puts "CANDIDATES ENTITY LABELS"
    puts candidates

    data.each{|s,p,o|
    # puts o
    # puts o.to_f
    # puts  (o.to_f.to_s.size != o.to_s.size)
    # puts  (o.to_f == 0)

      labels << p if !$textp.include?(p) and candidates.include?(p) and o.instance_of?(String) and o.size > 3 and (o.to_i.to_s.size != o.to_s.size and o.to_f.to_s.size != o.to_s.size)  #and (o.to_i == 0)
    }
    labels.uniq!
    # if labels.size > 10
    # labels = []
    # data.each{|s,p,o|
    # if !$textp.include?(p) and candidates.include?(p) and o.instance_of?(String) and (o.to_i == 0)
    # labels << p
    # # puts
    # # puts o.to_i
    # end
    # }
    # end
    $textp=nil
    labels.uniq!
    labels = candidates.delete_if{|x| !labels.include?(x)}.compact
    puts "ENTITY LABELS FOUND"
    puts labels
    labels=labels[0..2]
    puts "ENTITY LABELS SELECTED"
    labels.insert(0,"<http://www.w3.org/2000/01/rdf-schema#label>")
    labels.map!{|x| x.to_s}
    labels.uniq!
    puts labels
    labels
  # exit
  end

  ##############################################################
  def get_ambiguous(type, limit, offset, labelproperties)
    @searchedlabels = []

    subjects = nil
    begin

    # subjects = Query.new.adapters($session[:source]).sparql("select distinct ?s where {?s ?p #{type} . ?s   <http://www.okkam.org/ontology_person1.owl#age> ?o } order by ?o   offset #{offset} limit #{limit} ").execute
      subjects = Query.new.adapters($session[:source]).sparql("select distinct ?s where {?s ?p #{type} .}  offset #{offset} limit #{limit} ").execute
    rescue Exception => e
      puts e.message
      subjects = Query.new.adapters($session[:source]).sparql("select distinct ?s where {?s ?p #{type} .}  offset #{offset} limit #{limit} ").execute
    end

    data = subjects.map{|s|
      puts s
      # if s.to_s.index("C0001418") != nil
      # puts s
      # puts $offset
      # exit
      # end
      el = []
      keywords= []
      ambiguous = []
      labelproperties.each{|labelproperty|
        begin

          keywords = keywords + Query.new.adapters($session[:source]).sparql("select distinct ?o where { #{s} #{labelproperty} ?o. }").execute.flatten.compact
        rescue Exception => e
          keywords = keywords + Query.new.adapters($session[:source]).sparql("select distinct ?o where { #{s} #{labelproperty} ?o. }").execute.flatten.compact
        end
        # keywords.compact!
        # keywords.map!{|x|
        # y =  x.split("(")
        # if y == nil
        # x
        # else
        # y[0]
        # end
        # }
        keywords.delete_if {|b| b.to_s.size > 150 }

        ambiguous =   search((keywords + keywords.map{|k| k.singularize }).uniq.compact.map{|x| x.downcase}.uniq.compact)
        break if ambiguous.compact.size > 0
      }
      @searchedlabels << keywords
      ambiguous.compact.uniq.each{|a| el = el + a}
      el.uniq
    }

    $textp = get_text_properties(data) if $textp == nil
    puts "TEXT PROPERTIES USED"
    puts $textp
    entity_label_filtering(data)

    remove_idx = []
    data.each_index{|x|
    #            puts "############ 111"
    #             puts subjects[x]
    #            puts data[x]
    #            puts "############ 222"
      remove_idx << x if data[x].size == 0
    }
    remove_idx.reverse.each{|x|
      @searchedlabels.delete_at(x)
      subjects.delete_at(x)
      data.delete_at(x)
    }

    [subjects,data]
  end

  #####################################################################################################
  def web_build_sample(data,subjects)
    puts "**************************** BUILDING SAMPLE"
    puts data.size
    puts "*************************** PIVOT SIZE"
    puts $pivot.map{|x| x.map{|s,p| s}.uniq}
    pivot_size = $pivot.size
    $origin_subjects =  subjects.map{|s|
      begin
        Query.new.adapters($session[:source]).sparql("select distinct ?p ?o where { #{s} ?p ?o. }").execute
      rescue Exception => e
        e.message
        Query.new.adapters($session[:source]).sparql("select distinct ?p ?o where { #{s} ?p ?o. }").execute
      end
    }

    @searchedlabels = @searchedlabels + $pivot_labels

    svmbygroup = rdf2svm_with_meta_properties(data + $pivot, [])

    # puts "SVM GROUP AFTER PROCESSING"
    # puts svmbygroup.size
    svmbygroup = svmbygroup[0..(svmbygroup.size - pivot_size - 1 )] if pivot_size > 0

    annotated =[]

    ############## PRINT RESULTS OF MEASURES
    svmbygroup.each{|g| puts "######"
      puts g
    }

    puts "MODEL DONE"
    puts svmbygroup.size
    puts subjects.size
    idx = -1

    File.open($output, 'a') {|f|
      all_values = []
      maximus=[]
      svmbygroup.each{|svm|
        svm.map!{|x| x[(x.index(":") + 1)..x.size].to_f}
        maximus << svm.max
        all_values = all_values + svm
      }

      mean_maximus=mean(maximus)
      puts "MEAN OF MAXIMUS"
      puts mean_maximus
      all_values = all_values + [1.0] if !all_values.include?(1.0)
      global_mean_deviation = mean_and_standard_deviation(all_values)
      puts "MEAN / DEVIATION"
      puts global_mean_deviation
      outliers_threshold = [ (global_mean_deviation[0]  - global_mean_deviation[1]), global_mean_deviation[1]].max
      # outliers_threshold =  (global_mean_deviation[0]  - global_mean_deviation[1])
      puts "OUTLIER THRESHOLD"
      puts outliers_threshold
      # svmbygroup.each{|svm|
      # if !(svm.size == 1 and global_mean_deviation[1] >=0.1 and svm[0] < outliers_threshold)
      # max = svm.max
      # svm.map!{|v| v.to_f/max.to_f}
      # end
      # }
      #remove the pivots to generate the alignment
      # svmbygroup = svmbygroup[0..(svmbygroup.size - pivot_size - 1 )] if pivot_size > 0

      svmbygroup.each{|svm|
        idx=idx+1
        # puts idx
        groupedsubjects = data[idx].map{|s,p,o| s}.uniq
        ########################### Calculates the threshold
        mean_stdev =  mean_and_standard_deviation(svm)
        final_threshold = mean_stdev[0]
        if mean_stdev[1] > 0.1 and svm.max >= mean_maximus
          final_threshold = mean([svm.max,mean_maximus])
        end
        if global_mean_deviation[1] > 0.13
          final_threshold = [final_threshold , outliers_threshold].max
        end

        # if global_mean_deviation[1] > 0.10
        # final_threshold = [global_mean_deviation[0],outliers_threshold].max
        # else
        # final_threshold = global_mean_deviation[0]
        # end

        final_threshold = 0.99 if final_threshold == 1
        final_threshold = final_threshold + 0.01 if outliers_threshold == final_threshold
         final_threshold = mean_and_standard_deviation(svm.map{|v| v if v >=0.1}.compact)[0] if final_threshold < 0.1 and svm.max >= 0.1
        puts "FINAL THRESHOLD - " + idx.to_s
        puts final_threshold
        # max = svm.max
        # svm.map!{|v| v.to_f/max.to_f}
        ##################################################
        svm.each_index{|i|
          line = svm[i]
          final_threshold=  $rdsthreshold if $rdsthreshold != nil
          if $format == "txt"
            f.write(subjects[idx].to_s.gsub(/[<>]/,"") + "=" + groupedsubjects[i].to_s.gsub(/[<>]/,"") + "\n" ) if line >=  final_threshold
          # f.write(subjects[idx].to_s.gsub(/[<>]/,"") + "=" + groupedsubjects[i].to_s.gsub(/[<>]/,"") + "\n" ) if line >= $T1
          else
            f.write(subjects[idx].to_s  + " <http://www.w3.org/2002/07/owl#sameAs> " + groupedsubjects[i].to_s + ".\n" ) if line >=  final_threshold
          end
        }
      }
    }
  end

  def median(x)
    sorted = x.sort
    mid = x.size/2
    sorted[mid]
  end

  def mean(array)
    array.inject(0) { |sum, x| sum += x } / array.size.to_f
  end

  def mean_and_standard_deviation(array)
    m = mean(array)
    variance = array.inject(0) { |variance, x| variance += (x - m) ** 2 }
    return m, Math.sqrt(variance/(array.size))
  end

  def dbpedia_redirect(s)
    "Post PROCESSING DBPEDIA URIS"
    puts s
    r=[]
    begin
      r= Query.new.adapters($session[:target]).sparql("select distinct  ?o where { <#{s}> <http://dbpedia.org/ontology/wikiPageRedirects> ?o. }").execute

    rescue Exception => e
      puts e.message
      r=Query.new.adapters($session[:target]).sparql("select distinct  ?o where { <#{s}> <http://dbpedia.org/ontology/wikiPageRedirects> ?o. }").execute[0].to_s

    end
    if r.size ==0
    s
    else
      r[0].to_s.gsub(/[<>]/,"")
    end
  end

  def get_text_properties(rdfdata)

    puts "Computing text properties ... "
    data = Array.new(rdfdata)
    triples=[]
    data.each{|group|
      triples = triples + group
    }
    triples.uniq!
    triples.compact!
    textp=[]
    triples.each{|s,p,o| textp << p if o.to_s.size > 400}
    textp.uniq
  end

  def mount_adapter(endpoint, method=:post,cache=true)
    puts "Mounting adapter for sparql endpoint " + endpoint
    adapter=nil

    adapter = ConnectionPool.add_data_source :type => :sparql, :engine => :virtuoso, :title=> endpoint , :url =>  endpoint, :results => :sparql_xml, :caching => cache , :request_method => method

    return adapter
  end

  def order()
    check_result("sider","dailymed")
  end
end


String.class_eval do
  def singularize
    ActiveSupport::Inflector.singularize(self)
  end

end