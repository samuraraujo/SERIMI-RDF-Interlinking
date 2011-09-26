#Serimi Functionalities.
#It implements search function used in the matching process
#Author: Samur Araujo
#Date: 10 september 2011.
#License: SERIMI is distributed under the LGPL[http://www.gnu.org/licenses/lgpl.html] license. 
require "matching_module.rb"

def query_by_offset (type, limit, offset)
  query = "select distinct ?s where {?s ?p #{type}  }  offset #{offset} limit #{limit} "

  if type.index("select distinct") != nil
    query = "#{type} offset #{offset} limit #{limit} "
  end

  begin
    subjects = Query.new.adapters($session[:origin]).sparql(query).execute
  rescue Exception => e
    puts "Exception 4 for: #{query}"
    puts e.message
    subjects = Query.new.adapters($session[:origin]).sparql(query).execute
  end
end

def query_by_blocking (type, limit, offset,labelproperties)
  $bdata = sort_source_by_label(type,labelproperties) if $bdata == nil
  puts "sorted data"
   
  return $bdata[offset..(offset+limit-1)]
end

#label is the label with highest entropy in the source dataset

def sort_source_by_label(klass, labels)
  puts "sort_source_by_label"
  puts klass
  puts labels
  data = []
  labels.each{|label|
    data = Query.new.adapters($session[:origin]).sparql("select distinct ?s ?o where {?s #{label} ?o. ?s ?p #{klass}}  ").execute
    break if data.size != 0
  }

  data.map!{|s,o| [s,o.to_s.keyword_normalization]}
  hash = Hash.new
  data = data.each{ |s,o|
    x = o.split(" ")
    x.each{|w|
      hash[w] = Array.new if hash[w]  == nil
      hash[w] << [s]
    }
  }
  values =[]
  hash.values.sort{|a,b| b.size <=> a.size}.each{|v| values = values + v}
  values.uniq!
  return values
end



#search for resources

def search(keywords)
  $found=nil
  # puts "KEYWORDS"
  # puts keywords
  data=[]
  # keywords=keywords.map {|b| b.split("(")[0].to_s.rstrip } # eliminates everything between parenteses
  keywords.each{|x|
    x.gsub!("*"," ")
    x.gsub!(/"/,"")
    next if x.size < 3
    # if x.index ("singapore") != nil
    # puts $offset
    # exit
    # return
    # end
    b=[]
    # $label.each{|h|
    # puts "FOUND KEYS"
    # puts $word_by_word_properties
    $word_by_word_properties.each{|h|
      begin
        b = b + Query.new.adapters($session[:target]).sparql("SELECT DISTINCT ?s ?e ?r  WHERE { ?s ?e ?r . ?s #{h} ?o . ?o bif:contains  '\"#{x.gsub(/'/,"\\\\'")}\"'  . } " ).execute
        # puts b
      rescue Exception => ex
        puts "Exception 51: #{x}"
        puts ex.message
        b = b + Query.new.adapters($session[:target]).sparql("SELECT DISTINCT ?s ?e ?r  WHERE { ?s ?e ?r . ?s #{h} ?o . ?o bif:contains  '\"#{x.gsub(/'/,"\\\\'")}\"'  . } " ).execute
      end
      b = filter(b,x.to_s)
      break if b.size > 0
    }
    if  b.size == 0   #applies word by word approach
      puts "and_search"
      b = and_search(x)
    end
    if b.size == 0 and $word_by_word #applies word by word approach
      puts "word_by_word_search"
      b = word_by_word_search(x)
    end
    # if  b.size == 0  #applies suffix removal approach
    # puts "suffix_removal_search"
    # b = suffix_removal_search(x, h)
    # end
    # puts "FOUND"
    # puts $found
    $word_by_word_properties.delete($found)
    $word_by_word_properties = [$found] + $word_by_word_properties if $found != nil
    puts "End Search"
    b.uniq!
    # puts b.size
    # puts b
    # b = dbpedia_filter(b) if params[:origin] == "dbpedia" || params[:target] == "dbpedia"
    data << b
  # puts data.size
  # puts data

  }
  data.map!{|t| t if t[0] != nil}
  data.compact!
  data
end



def and_search(x)
  b=[]
  $word_by_word_properties.each{|h|
    k = x.keyword_normalization.split(" ")
    # splited = k - $stopwords
    splited = k #if splited.size < 2
    # puts splited

    while b.size == 0
      break  if splited.size < 2
      z= splited.map{|f| "\"#{f}\""}.join("AND")
      c=[]
      begin
        b = Query.new.adapters($session[:target]).sparql("SELECT DISTINCT ?s ?e ?r  WHERE { ?s ?e ?r . ?s #{h} ?o . ?o bif:contains  '#{z.gsub(/'/,"\\\\'")}'  . } " ).execute
      rescue Exception => ex
        puts "Exception 52: #{x}"
        puts ex.message
        b = Query.new.adapters($session[:target]).sparql("SELECT DISTINCT ?s ?e ?r  WHERE { ?s ?e ?r . ?s #{h} ?o . ?o bif:contains  '#{z.gsub(/'/,"\\\\'")}'  . } " ).execute
      end
      b = filter(b,x.to_s)
      splited.delete_at(splited.size-1)
    end
  }
  ######################
   c=[]
  $word_by_word_properties.each{|h|
    k = x.keyword_normalization.split(" ")
    splited = k - $stopwords
    break  if splited.size < 2
    z= splited.map{|f| "\"#{f}\""}.join("AND")
   
    begin
      c= Query.new.adapters($session[:target]).sparql("SELECT DISTINCT ?s ?e ?r  WHERE { ?s ?e ?r . ?s #{h} ?o . ?o bif:contains  '#{z.gsub(/'/,"\\\\'")}'  . } " ).execute
    rescue Exception => ex
      puts "Exception 52: #{x}"
      puts ex.message
      c = Query.new.adapters($session[:target]).sparql("SELECT DISTINCT ?s ?e ?r  WHERE { ?s ?e ?r . ?s #{h} ?o . ?o bif:contains  '#{z.gsub(/'/,"\\\\'")}'  . } " ).execute
    end
    c = filter(c,x.to_s)
    break if c.size > 0
  }
   return b + c
end



def word_by_word_search(x)

  b=[]
  splited = x.keyword_normalization.split (" ")
  splited.each{|z|
    next if $stopwords.include?(z.removeaccents)
    next if z.size < 3
    c=[]
    $word_by_word_properties.each{|pre|
        
      next if c.size > 0
      begin
        c = Query.new.adapters($session[:target]).sparql("SELECT DISTINCT ?s ?e ?r  WHERE { ?s ?e ?r . ?s #{pre} ?o . ?o bif:contains  '\"#{z.gsub(/'/,"\\\\'")}\"'  . } " ).execute
      rescue Exception => ex
        puts "Exception 52: #{x}"
        puts ex.message
        c = Query.new.adapters($session[:target]).sparql("SELECT DISTINCT ?s ?e ?r  WHERE { ?s ?e ?r . ?s #{pre} ?o . ?o bif:contains  '\"#{z.gsub(/'/,"\\\\'")}\"'  . } limit 5000 " ).execute
      end
      c = filter(c,x.to_s)
      b = b + c
    # return b if b.size > 0  and $stopwords.size == 0
    }
    break if b.size > 0

  }
  b
end



# def suffix_removal_search(x,h)
# b=[]
# splited = x.keyword_normalization.split (" ")
# while true
# return b if splited.size <= 2
# splited.delete_at((splited.size-1))
# y = splited.join(" ")
# next if y.size < 3
# next if $stopwords.include?(y.removeaccents)
# begin
# b = b + Query.new.adapters($session[:target]).sparql("SELECT DISTINCT ?s ?e ?r  WHERE { ?s ?e ?r . ?s #{h} ?o . ?o bif:contains  '\"#{y.gsub("'","\\'")}\"'  . } " ).execute
# rescue Exception => ex
# puts "Exception 53: #{x}"
# puts ex.message
# b = b + Query.new.adapters($session[:target]).sparql("SELECT DISTINCT ?s ?e ?r  WHERE { ?s ?e ?r . ?s #{h} ?o . ?o bif:contains  '\"#{y.gsub("'","\\'")}\"'  . } " ).execute
# end
#
# b = filter(b,x.to_s)
# return b if b.size > 0
#
# end
# b
# end

################################### FILTER ###################################################

def filter(data,keyword )
  data.uniq!
  # puts "Filtering ..."
  current=nil
  filtered=[]
  newdata =[]
  measure=false

  data = yago_filter(data)  if $dbpedia
  data=blank_node_remover(data)
  
  return newdata if data.size == 0

  subjects = data.map{|s,p,o| s}.uniq
  groupedsubject = subjects.map{|x| data.find_all{|s,p,o| s==x}}
  groupedsubject.each{|group|
    measure=false
    group.each{|s,p,o|

      next if  $textp != nil && $textp.include?(p)
      next if o.instance_of? RDFS::Resource
      next if  $textp == nil && o.to_s.size > (3 * keyword.size)
      puts s
      puts p
      score=0
      # if o.to_s.downcase.jarowinkler_similar(keyword.downcase).to_f > $filter_threshold
      y = o.to_s

      score = advanced_string_matching(keyword,y)

      if score > $filter_threshold
        $found=p
      measure=true
      break
      end
    }
    if measure
    newdata = newdata + group
    end
  }

  newdata
end

######################################################
 def blank_node_remover(data)
     data.delete_if{|s,p,o|   s.class.to_s == 'BNode'  } 
       
    # blanknodes.each{|b|
#        
     # result=Query.new.adapters($session[:target]).sparql("SELECT DISTINCT ?s ?p ?o  WHERE { ?s ?p ?o . ?o #{data.find_all{|s,p,o| s==b and o.class == String}.map{|s,p,o| [p,o]}.first.join(' ')}  . } " ).execute
     # exit
     # expanded_subjected=result.first.first
       # data.map!{|s,p,o| 
          # if s==b
            # [expanded_subjected,p,o]
          # else
            # [s,p,o]  
          # end
          # }
          # data = data + result 
      # } 
      
      return data
  end
   def yago_filter(data) 
    puts "REMOVING yago ..."
    data.delete_if{|s,p,o|  s.to_s.index("http://dbpedia.org/class/yago/") != nil }.compact!
    data
  end
  def dbpedia_filter(data)
    puts "REMOVING wikiPageRedirects ..."
    subjectstoremove = data.map{|s,p,o|  s if p.to_s.index("wikiPageRedirects") != nil }.compact.uniq
    puts subjectstoremove
    data.delete_if{|s,p,o|  subjectstoremove.include?(s) }.compact!
    data
  end
