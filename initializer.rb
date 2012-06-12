#Serimi Functionalities.
#Author: Samur Araujo
#Date: 10 April 2011.
#License: SERIMI is distributed under the LGPL[http://www.gnu.org/licenses/lgpl.html] license. 
require './active_rdf/lib/active_rdf'
require './activerdf_sparql-1.3.6/lib/activerdf_sparql/init'
require 'active_support/inflector'
require "search_module.rb"

$label=["?p"]
$session = Hash.new
module Initializer_Module
  def initialize(params)
    
    $usepivot=false
    $topk=params[:topk].to_i 
    $output=params[:output]
    $format=params[:format]
    $filter_threshold=params[:stringthreshold]
    $rdsthreshold=params[:rdsthreshold]
    $usepivot=true if params[:usepivot] ==  'true'
    $blocking=true  if params[:blocking] ==  'true'
    if params[:append] == 'w'
      File.delete($output) if  File.exist?($output) 
    end  
 
    $removelabels=[]
      
    
    $t1=Time.now
    count = 0
    manual_offset=params[:offset]

    origin_endpoint=params[:source]

    target_endpoint=params[:target]
    
    $dbpedia = params[:target].index("dbpedia") != nil

    $session[:origin] = mount_adapter(origin_endpoint,:post,false)
    $session[:target] = mount_adapter(target_endpoint,:post,false)
        
     limit = $TH = params[:chunk]

    $textp = nil

    classes = [ "<"+ params[:class] + ">"]

    start = true
    delete = true
    # $lastclass=nil
 classes.each{|s|

      puts "PROCESSING CLASSES"
      puts s
      puts " LAST CLASS"
      puts $lastclass
      $pivot = []
      $bdata=nil 
      $word_by_word_properties=["?p"]
      $pivot_labels = []
      $pivot_subjects = []
      if $lastclass != nil && start
      next if s != $lastclass
      start = false
      end

      klass = s
      $lastclass= klass
      labels =  get_entity_labels(klass)

      count =  Query.new.adapters($session[:origin]).sparql("select distinct count(?s) where {?s ?p #{klass} . }").execute[0][0].to_i
       if $blocking
        $bdata = sort_source_by_label(klass,labels) if $bdata == nil
        count = $bdata.size
      end
      offset = 0
      puts  "PREVIOUS OFFSET"
      puts $offset

      # manual_offset= count - 50
      # manual_offset=975

      $offset=manual_offset if manual_offset > 0 and $offset == nil 
      offset = $offset.to_i  if $offset != nil

      puts "STARTING FROM OFFSET " + offset.to_s
      puts "NUMBER OF INSTANCES"
      puts count
      #GET FIRST PIVOT
      limit = count if limit > count
      get_first_pivot(klass,5, offset, labels) if $usepivot
      while offset <= count and limit <= count    do
        if offset == 0 
        limit = 5
        elsif offset == 5
        limit = $TH
        end
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
           if offset == 0 
            offset = 5
            limit = limit + offset
          end
          puts "CHANGING LIMIT TO " + limit.to_s
        next
        end
        next if data.size == 1 or data.size == 0

        $subjects=subjects.map{|x| x[0].label}
        
        web_build_sample(data,subjects)
      # break if offset > 20
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
  #####################################################################################################
  def web_build_sample(data,subjects)
    puts "**************************** BUILDING SAMPLE"
    puts data.size
    puts "*************************** PIVOT SIZE"
    puts $pivot.map{|x| x.map{|s,p| s}.uniq}
    pivot_size = $pivot.size
    $origin_subjects =  subjects.map{|s|
      begin
        Query.new.adapters($session[:origin]).sparql("select distinct ?p ?o where { #{s} ?p ?o. }").execute
      rescue Exception => e
        puts "Exception 1: select distinct ?p ?o where { #{s} ?p ?o. }"
        e.message
        Query.new.adapters($session[:origin]).sparql("select distinct ?p ?o where { #{s} ?p ?o. }").execute
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
        if $topk == 0
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
        else
          final_threshold = svm.sort{|a,b| b <=> a}[$topk-1]
        end

        puts "FINAL THRESHOLD - " + idx.to_s
        puts final_threshold

         ##################################################
        svm.each_index{|i|
          line = svm[i]
          final_threshold= $rdsthreshold if $rdsthreshold != nil
          if $format == "txt"
            f.write(subjects[idx].to_s.gsub(/[<>]/,"") + "=" + groupedsubjects[i].to_s.gsub(/[<>]/,"") + "\n" ) if line >= final_threshold
          # f.write(subjects[idx].to_s.gsub(/[<>]/,"") + "=" + groupedsubjects[i].to_s.gsub(/[<>]/,"") + "\n" ) if line >= $T1
          else
            f.write(subjects[idx].to_s + " <http://www.w3.org/2002/07/owl#sameAs> " + groupedsubjects[i].to_s + ".\n" ) if line >= final_threshold
          end
        }
      }
    }
  end

   def mount_adapter(endpoint, method=:post,cache=true) 
    adapter=nil
    begin 
      adapter = ConnectionPool.add_data_source :type => :sparql, :engine => :virtuoso, :title=> endpoint , :url =>  endpoint, :results => :sparql_xml, :caching => cache , :request_method => method
      
    rescue Exception => e
      puts e.getMessage()
      return nil
    end
    return adapter
  end   
end