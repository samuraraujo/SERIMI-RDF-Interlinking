#Serimi Functionalities.
#Author: Samur Araujo
#Date: 10 April 2011.
#License: SERIMI is distributed under the LGPL[http://www.gnu.org/licenses/lgpl.html] license.
require '../active_rdf/lib/active_rdf'
require '../activerdf_sparql-1.3.6/lib/activerdf_sparql/init'



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



def wikipageredirect(o)

  result =  Query.new.adapters($session).sparql("select distinct ?s where { <#{o}>   <http://dbpedia.org/ontology/wikiPageRedirects> ?s }  ").execute[0]

  result =  Query.new.adapters($session).sparql("select distinct ?s where {  ?s <http://dbpedia.org/ontology/wikiPageRedirects>  <#{o}> }  ").execute[0] if result == nil || result.size == 0

  if result == nil || result.size == 0
  o
  else
    result.to_s.gsub(">","").gsub("<","")
  end
end

def endpage (uri) 
  response = Net::HTTP.get_response(URI.parse(uri)) 
  if response.code.to_i != 200 
    endpage(response['location'])
  end
  return uri
end

def sameas(origin)

  origin_endpoint = origin
  $session = mount_adapter(origin_endpoint,:post,false)
  
 target_endpoint = "http://dbpedia.org/sparql"
  dbpedia = mount_adapter(target_endpoint,:post,false)
  
  q = "select distinct count(?o) where {?s <http://www.w3.org/2002/07/owl#sameAs> ?o . filter (regex(str(?o), 'http://dbpedia.org/resource/'))}"

  count =  Query.new.adapters($session).sparql(q).execute[0][0].to_i
  puts count
  current = 0 
  limit = 10000
  offset = 0
  lines_redirected = 0 
  lines_ambiguous = 0 
  redirected = File.open("./redirected.txt", 'w')
  ambiguous = File.open("./ambiguous.txt", 'w')  

    while offset < count
      
      q = "select distinct (?o) where {?s <http://www.w3.org/2002/07/owl#sameAs> ?o . filter (regex(str(?o), 'http://dbpedia.org/resource/'))} limit #{limit} offset #{offset}"

      links =  Query.new.adapters($session).sparql(q).execute
      links.each{|x|
        current = current  + 1
        puts current
        begin
        q = "select distinct (?o) where {#{x} <http://dbpedia.org/ontology/wikiPageRedirects> ?o } "
        r=  Query.new.adapters(dbpedia).sparql(q).execute
        
        if r != nil && r.size > 0
          redirected.write(x)
          redirected.write("\n")
          lines_redirected = lines_redirected + 1
       
          if r.to_s.index("disambiguation") != nil
          ambiguous.write(x)
          ambiguous.write("\n")
          lines_ambiguous = lines_ambiguous + 1 
          end
        end
        rescue Exception => e
          puts e.message
        end

      }
      offset = offset + limit
    end
   
  puts "count"
  puts count
  puts "lines_redirected"
  puts lines_redirected
  
  puts "ratio redirected"
  puts (lines_redirected.size.to_f / count.to_f)
  
   puts "lines_ambiguous"
  puts lines_ambiguous
  
  puts "ratio ambiguous"
  puts (lines_ambiguous.size.to_f / count.to_f)
  
end
sameas("http://lsd.taxonconcept.org/sparql")
