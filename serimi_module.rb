module Serimi_Module
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

  ##############################################################################################################################
  def entity_label_filtering(rdfdata)
    puts "Filtering Data by Entity Label"
    discriminative_predicates=[]
    result_entropy = entropy_computation(rdfdata)
    discriminative_predicates = result_entropy[0]
    entropies = result_entropy[1]
    # puts entropies
    puts "ENTITY LABELS FOR FILTERING"
    puts discriminative_predicates
    puts "################################"
    $word_by_word_properties.delete("?p")
    $word_by_word_properties= ($word_by_word_properties + discriminative_predicates)[0..5]
    $word_by_word_properties.uniq!

    ######################## SELECTING RESOURCE WITH MAXIMUM STRING SIMILARITY MEASURE PER GROUP ##########################
    count=-1
    rdfdata.map!{|group|
      count=count+1
      if group.size > 0
        # puts "Selecting Maximum String Similarity Resources"
        # puts "SELECTING RESOURCES"
        # puts group.size
        # puts group.map{|s,p| s}.uniq
        # max = 0
        maximas = group.map{|s,p,o|
          entitylabel = discriminative_predicates.include?(p)
          entitylabel= true if discriminative_predicates.size == 0 # not enough information was used to compute the entropy
          entitylabel = true if (o.to_s.to_i != 0)

          $word_by_word_properties.delete_if{|p1| p1 == p and o.instance_of?(RDFS::Resource)  }
          # puts "@@@@@"
          # puts p
          # puts (entropies[p])
          # puts "@@@@@"
          [s,p,o, (o.instance_of?(RDFS::Resource) or $textp.include?(p) or !entitylabel) ? 0 : (max_jaro(o.to_s, @searchedlabels[count],s).to_f ) , entropies[p] == nil ? 0 : 1-entropies[p]]   }
        # maximas = group.map{|s,p,o|  [s,p,o, (o.instance_of?(RDFS::Resource) or $textp.include?(p)  ) ? 0 : max_jaro(o.to_s, @searchedlabels[count],s).to_f ]   }

        max = maximas.map{|s,p,o,m| m.to_f }.max

        # puts  "MAXIMA"
        # puts max
        selection = []
        selection = maximas.map{|s,p,o,m,e| s if m == max }.uniq.compact if max > $filter_threshold
        # selection = maximas.map{|s,p,o,m,e| s if m > $filter_threshold  }.uniq.compact
        # maximas = maximas.map{|s,p,o,m,e| [s,p,o,m,e] if m == max}.uniq.compact if max > $filter_threshold
        # max_entropy = maximas.map{|s,p,o,m,e| e }.max
        # selection = maximas.map {|s,p,o,m,e| s if   e == max_entropy}.uniq.compact  if max > $filter_threshold
        # puts maximas.map{|s,p,o,m| [s,o] if  m == max}.uniq
        # puts selection
        group.delete_if{|s,p,o|  !selection.include?(s)}.compact
        # puts "AFTER SELECTION"
        # puts group.map{|s,p| s}.uniq

        #Special processing for dbpedia due to redirect resources.
        #processing redirect resources

        group = dbpedia_redirect(group)  if $dbpedia
      end
      group

    }

  end

  def dbpedia_redirect(data)

    redirect = []

    data.each{|s,p,o| redirect << [s,o] if p.to_s.index("wikiPageRedirects") != nil }
    return data if redirect.size == 0
    redirect.uniq!
    subjects = redirect.map{|s,p| s}

    data.delete_if{|s,p,o| subjects.include?(s)   }
    redirect.each{|s,o|
      b= nil
      begin
        b =  Query.new.adapters($session[:target]).sparql("SELECT DISTINCT  ?p ?o  WHERE { #{o} ?p ?o  . } " ).execute
      rescue Exception => ex
        puts "Exception 3 for: #{o}"
        b =  Query.new.adapters($session[:target]).sparql("SELECT DISTINCT  ?p ?o  WHERE { #{o} ?p ?o  . } " ).execute
        puts "******************* EXCEPTION *****************"
        puts ex.message
      end
      b.map!{|p,x| [o,p,x]}
      data = data + b
    }
    data.uniq
  end

  #############################################################################################
  def max_jaro (a,labels,s)
    # puts "COMPUTING MAX JARO ... "
    # puts s
    c = 0
    # puts "LABELS"
    # puts labels
    # puts "-------"
    labels.each{|x|
    # c = c + a.jarowinkler_similar(x.downcase)
      c = c + advanced_string_matching(a, x)
    }
    # puts a
    # puts c
    c
  end

  require 'date'

  def valid_date?( str)
    Date.strptime(str,"%m/%d/%Y" ) rescue Date.strptime(str,"%Y-%m-%d" )  rescue false
  end

  ##############################################################
  def get_ambiguous(type, limit, offset, labelproperties)
    @searchedlabels = []
    subjects=[]
    if $blocking
      subjects = query_by_blocking(type, limit, offset, labelproperties)
    else
      subjects = query_by_offset(type, limit, offset)
    end
    subjects.delete_if{|x| x[0].class.to_s == 'BNode'  }
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
        keywords= []
        begin
          keywords = keywords + Query.new.adapters($session[:origin]).sparql("select distinct ?o where { #{s} #{labelproperty} ?o. }").execute.flatten.compact
        rescue Exception => e
          puts "Exception for: select distinct ?o where { #{s} #{labelproperty} ?o. }"
          keywords = keywords + Query.new.adapters($session[:origin]).sparql("select distinct ?o where { #{s} #{labelproperty} ?o. }").execute.flatten.compact
        end
        keywords.compact!
        keywords.delete_if {|b| b.to_s.size > 150 } # eliminates text
        keywords.delete_if {|b| valid_date?(b.to_s) != false } # eliminates date
        keywords=keywords.map {|b| b.split("(")[0].to_s.rstrip } # eliminates everything between parenteses
        keywords.uniq!

        ambiguous = search(keywords)
        puts "Searched Ambiguous"

        break if ambiguous.compact.size > 0
      }
      # I added the ext_keywords because the string threshold can be too high for some cases.
      # I decided to do that because I found problem in the nytimes-freebase people interliking.
      @searchedlabels << keywords

      ambiguous.compact.uniq.each{|a| el = el + a}
      el.uniq
    }

    $textp = get_text_properties(data) if $textp == nil
    puts "TEXT PROPERTIES USED"
    puts $textp
    puts "END"

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
        Query.new.adapters($session[:origin]).sparql("select distinct ?p ?o where { #{s} ?p ?o. }").execute
      rescue Exception => e
        puts "Exception 2 for: #{s}"
        e.message
        Query.new.adapters($session[:origin]).sparql("select distinct ?p ?o where { #{s} ?p ?o. }").execute
      end
    }
    rdf2svm_with_meta_properties(data , [])

    puts "End of Obtaining First Pivot"
  end

  ## GET ENTITY LABELS
  def get_entity_labels(klass)
    puts "get_entity_labels"

    data=[]
    if klass.index("select distinct") != nil
      data = Query.new.adapters($session[:origin]).sparql(klass + " limit #{4000} ").execute
    else
      data = Query.new.adapters($session[:origin]).sparql("select distinct ?s ?x ?o where {?s ?x ?o . ?s ?p #{klass} .}   limit #{4000} ").execute
    end

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
    $stopwords= get_stop_words(klass,labels)
    labels

  end

  def get_stop_words(klass, labels)
    puts "STOP WORDS"
    all_stopwords=[]
    data=[]
    labels.each{|label|
      puts "STOP WORDS FOR LABEL: "
      puts label
      stopwords=[]

      data = Query.new.adapters($session[:origin]).sparql("select ?o where {?s #{label} ?o. ?s ?p #{klass}}").execute
      next if data.size == 0
      words=Hash.new

      str = data.map{|o| o.to_s.keyword_normalization.split(" ")}.flatten
      str.each{|x|
        next if x.to_i != 0
        next if x == nil
        # puts x
        words[x] = 0 if words[x] == nil
        words[x] = words[x] + 1
      }
      next if words.size == 0
      size = data.size
      puts "SIZE"
      puts size
      words.each{|x,v|
      # puts x
      # puts v
        words[x] = v.to_f / size.to_f
      }
      # words.sort.each{|x,v|
      # puts x
      # puts v
      #
      # }
      puts "MEDIA / STDEV"
      mm =  mean_and_standard_deviation(words.values)
      mean= mm[0].to_f
      stdev = mm[1].to_f

      puts mean
      puts stdev
      puts "Threshold"
      threshold = mean
      puts threshold
      next if stdev < (mean * 2)
      words = sort(words)
      words.each{|x,v|
      # puts x
      # puts v
        x = x.keyword_normalization.removeaccents
        stopwords << x if v >= (threshold) and x.size > 1
      } #if stdev > 0.1
      stopwords.uniq!
      stopwords =stopwords.sort_by{|x| x.size}
      stopwords.reverse!

      puts stopwords
      puts "END"
      puts stopwords.size
      all_stopwords=all_stopwords + stopwords
    }
    all_stopwords
  end

  ####################################
  def getCode(v)
    ####################################
    #    puts "Getting Code"
    #    @codes=Array.new if @codes == nil
    #    index = @codes.index(v)
    #    return index if index != nil
    #    @codes << v
    #    return @codes.size-1
    ####################################
    @counter=0 if @counter == nil
    @codes=Hash.new if @codes == nil
    c = @codes[v]
    if c == nil
    @counter=@counter+1
    @codes[v]=@counter
    c=@counter
    end
    ####################################
    return  c
  end

end