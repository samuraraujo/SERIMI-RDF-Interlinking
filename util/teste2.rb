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



def teste1( )

  puts "MOUNTING"
  origin_endpoint = "http://wisserver.st.ewi.tudelft.nl:8892/sparql?default-graph-uri=http://geonames.org" if $dataset == 'geonames'
  origin_endpoint = "http://dbpedia.org/sparql" if $dataset == 'dbpedia'
  $session = mount_adapter(origin_endpoint,:post,false)

  $t1=Time.now
  for i in 0..5
   results = Query.new.adapters($session).sparql("select distinct ?s  where {  ?s ?p <http://www.geonames.org/ontology#T>. ?s <http://www.w3.org/2003/01/geo/wgs84_pos#lat> '-14.0' }   ").execute if $dataset == 'geonames'
  results =  Query.new.adapters($session).sparql("select distinct ?s where {  ?s <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://dbpedia.org/class/yago/IslandsOfBrazil>. }  ").execute if $dataset == 'dbpedia'
  results.each{|x|
       Query.new.adapters($session).sparql("select distinct * where { #{x.to_s}  ?p ?o }  ").execute
  }
  end
  $t2=Time.now
  $tt1=$t2-$t1
end


def teste3( )

  puts "MOUNTING"
  origin_endpoint = "http://wisserver.st.ewi.tudelft.nl:8892/sparql?default-graph-uri=http://geonames.org" if $dataset == 'geonames'
  origin_endpoint = "http://dbpedia.org/sparql"  if $dataset == 'dbpedia'
  $session = mount_adapter(origin_endpoint,:post,false)

  $t1=Time.now
  for i in 0..5
   results = Query.new.adapters($session).sparql("select distinct ?s  where {  ?s ?p <http://www.geonames.org/ontology#T>. ?s <http://www.w3.org/2003/01/geo/wgs84_pos#lat> '-14.0' } limit 50  ").execute if $dataset == 'geonames'
  results =  Query.new.adapters($session).sparql("select distinct ?s where {  ?s <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://dbpedia.org/class/yago/IslandsOfBrazil>. }    ").execute if $dataset == 'dbpedia'
  count = 0
  q = results.map {|x| 
    count=count +1
    " {#{x.to_s}  ?p#{count}  ?o#{count} . }"  }.join (" union ")
  Query.new.adapters($session).sparql("select distinct * where { #{q}}  ").execute
  end
  
  $t2=Time.now
 $tt3=$t2-$t1

end

def teste2( )

  puts "MOUNTING"
  origin_endpoint = "http://wisserver.st.ewi.tudelft.nl:8892/sparql?default-graph-uri=http://geonames.org" if $dataset == 'geonames'
  origin_endpoint = "http://dbpedia.org/sparql"  if $dataset == 'dbpedia'
  $session = mount_adapter(origin_endpoint,:post,false)

  $t1=Time.now
  for i in 0..5 
     Query.new.adapters($session).sparql("select distinct ?s ?x ?r where {?s ?x ?r . ?s ?p <http://www.geonames.org/ontology#T>. ?s <http://www.w3.org/2003/01/geo/wgs84_pos#lat> '-14.0' }   ").execute if $dataset == 'geonames'
     Query.new.adapters($session).sparql("select distinct ?s ?x ?r where {?s ?x ?r . ?s <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://dbpedia.org/class/yago/IslandsOfBrazil>.  }   ").execute if $dataset == 'dbpedia'
  end
  $t2=Time.now
    
   
   $tt2=$t2-$t1

end
def teste4( )

  puts "MOUNTING"
  origin_endpoint = "http://wisserver.st.ewi.tudelft.nl:8892/sparql?default-graph-uri=http://geonames.org" if $dataset == 'geonames'
  origin_endpoint = "http://dbpedia.org/sparql"  if $dataset == 'dbpedia'
  $session = mount_adapter(origin_endpoint,:post,false)

  $t1=Time.now
  for i in 0..5
   results = Query.new.adapters($session).sparql("select distinct ?s  where {  ?s ?p <http://www.geonames.org/ontology#T>. ?s <http://www.w3.org/2003/01/geo/wgs84_pos#lat> '-14.0' } limit 50  ").execute if $dataset == 'geonames'
  results =  Query.new.adapters($session).sparql("select distinct ?s where {  ?s <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://dbpedia.org/class/yago/IslandsOfBrazil>. }    ").execute if $dataset == 'dbpedia'
   
  q = results.map {|x| 
    
    " { ?s  ?p  ?o . filter (?s = #{x.to_s}) }"  }.join (" union ")
  Query.new.adapters($session).sparql("select distinct * where { #{q}}  ").execute
  end
  
  $t2=Time.now
 $tt4=$t2-$t1

end
 $dataset = 'geonames'
 $dataset = 'dbpedia'
teste1()
teste2()
teste3()
teste4()

puts $tt1
 puts $tt2
 puts $tt3
 puts $tt4