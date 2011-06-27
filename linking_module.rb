module Linking_Module
  
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

  #search for resources
  def search(keywords)
    # puts "KEYWORDS"
    # puts keywords
 
    data=[]
    keywords.each{|x|
      next if x.size < 4
    # if x.index ("lactulose") != nil
    # puts $offset
    # exit
    # return
    # end
      x = x.gsub(/'/, "")
      b=[]
      $label.each{|h|
        begin
          b = b + Query.new.adapters($session[:target]).sparql("SELECT DISTINCT ?s ?e ?r  WHERE { ?s ?e ?r . ?s #{h} ?o . ?o bif:contains  '\"#{x}\"'  . } " ).execute
        rescue Exception => ex
          puts "******************* EXCEPTION *****************"
          puts ex.message
        end

      }
      b.uniq!

      # b = dbpedia_filter(b) if params[:origin] == "dbpedia" || params[:target] == "dbpedia"

      if $filter
        data << filter(b,x.to_s)
      else
      data << b
      end
    }
    data.map!{|t| t if t[0] != nil}
    data.compact
    data
  end

  def dbpedia_filter(data)

    puts "REMOVING wikiPageRedirects ..."
    subjectstoremove = data.map{|s,p,o|  s if p.to_s.index("wikiPageRedirects") != nil }.compact.uniq
    puts subjectstoremove
    data.delete_if{|s,p,o|  subjectstoremove.include?(s) }.compact!
    data
  end



  #gets keywords from the resources obtained from the origin rdf dataset
  def generate_keywords(resources)
    keywords=Array.new
    resources.flatten.each{|x|
      keywords << x.name
    }
    keywords
  end

  ################################### FILTER ###################################################
  def filter(data,keyword)
    # puts "Filtering ..."
    current=nil
    filtered=[]
    newdata =[]
    measure=false

    subjects = data.map{|s,p,o| s}.uniq
    groupedsubject =  subjects.map{|x| data.find_all{|s,p,o| s==x}}
    groupedsubject.each{|group|
      measure=false 
      group.each{|s,p,o|
        next if  $textp != nil && $textp.include?(p)
        if o.to_s.downcase.jarowinkler_similar(keyword.downcase).to_f > $filter_threshold
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

 
end