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



def fmeasure(a,b)
  return 0.0 if a == 0 || b == 0
  2.0 * (a * b)  / (a+b)
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



def check_result(origin, target)

  if target == "dbpedia"
    puts "MOUNTING"
    origin_endpoint = "http://dbpedia.org/sparql"
    $session = mount_adapter(origin_endpoint,:post,false)
  end

  #    [:drugbank ,    :dbpedia ,    :stitch ,    :tcm ,    :sider ,    :linkedct ,    :bio2rdf ,    :diseasome,     :dailymed ,    :yago ]
  #    linesbygroup = []
  solution=[]
  encountered=[]
  subjects=[]
  @recall=0
  @precision=0

  File.open("/Users/samuraraujo/tmp/alignment/#{origin}_#{target}.txt", 'r').each { |line|
    solution << line
  }
  File.open("/Users/samuraraujo/tmp/alignment/SER-#{origin}_#{target}.txt", 'r').each { |line|
    encountered << line#.gsub(",","%2C")
  }
  File.open("/Users/samuraraujo/tmp/alignment/log-subjects.txt", 'r').each { |line|
    subjects << line.rstrip
  }

   puts "NOT FOUND"
  puts subjects.uniq.size
  puts encountered.uniq.size
   
   
  golden = solution.map{|x| x.split("=")[0]}
  encountered.delete_if{|x| !golden.include?(x.split("=")[0]) }
  
   searched = encountered.map{|x| x.split("=")[0].to_s}
   puts subjects - searched
   puts "####" 
   solution.delete_if{|x| !subjects.include?(x.split("=")[0]) } 
  
 

  if  target == "dbpedia"
    
    puts "SOLUTION"
    solution.map! {|x|
      x = x.rstrip.split("=")
      x[0] + "="+ CGI::unescape(wikipageredirect(CGI::unescape(x[1])).to_s) }
    puts "ENCOUNTERED"
    encountered.map! {|x| x = x.rstrip.split("=") 
      x[0] + "="+ CGI::unescape(wikipageredirect(CGI::unescape(x[1])).to_s) }
  end
  solution.uniq!
  encountered.uniq!
  puts solution.sort
  puts "$$$$$$"
  puts encountered.sort

  puts "######## DIFFERENCE  encountered - solution"

  puts  encountered - solution

  puts "######## DIFFERENCE  solution - encountered"

  puts (solution - encountered)[0..10]

  positive = 0
  false_positive = 0
  negative = 0
  false_negative = 0

  positive = (solution & encountered).size
  false_positive = (encountered - solution).size
  false_negative = (solution - encountered).size
  # puts positive
  # puts  false_positive
  begin
    @precision =  (positive.to_f / (positive.to_f + false_positive.to_f))
  rescue
  @precision = 0.0
  end
  begin
    @recall = (positive.to_f / (positive.to_f + false_negative.to_f))
  rescue
  @recall = 0.0
  end

  puts "Precision"
  puts @precision
  puts "Recall"
  puts @recall
  puts "FMeasure"
  puts   fmeasure(@recall,@precision)
end



def recall(origin,target)
  solution= []
  encountered=[]
  searched =[]
  File.open("/Users/samuraraujo/tmp/alignment/#{origin}_#{target}.txt", 'r').each{ |line|
    solution << line.rstrip
  }
  File.open("/Users/samuraraujo/tmp/alignment/SER-#{origin}_#{target}.txt", 'r').each{ |line|
    encountered << line.rstrip
  }
  notfound =  solution - encountered
  File.open("searched.txt", 'r').each {|line|
    searched << line.rstrip
  }
  notfound.map!{|x| x[0..x.index("=")-1]}
  puts "NOTFOUND"
  puts notfound
  puts notfound.size
# puts "SEARCHED"
# # puts searched.sort
# searched.uniq!
# notfound.uniq!
#
# puts  searched & notfound
end

# check_result("sider","dailymed")
# check_result("sider","dbpedia")
# check_result("sider","diseasome")
# check_result("sider","drugbank")
# check_result("sider","tcm")
# check_result("sider","dbpedia")
# check_result("dailymed","linkedct")
# check_result("dailymed","tcm")
# check_result("dailymed","dbpedia")
# check_result("dailymed","sider")
# check_result("nytimes","dbpedia")

# check_result("person11","person12")
# check_result("person21","person22")
# check_result("restaurant1","restaurant2")

# check_result("drugbank","sider")
# check_result("diseasome","sider")

# check_result("NYT-people","dbpedia")
# check_result("NYT-locations","dbpedia")
# check_result("NYT-organizations","dbpedia")

# check_result("NYT-locations","geonames")

# check_result("NYT-locations","freebase")
# check_result("NYT-organizations","freebase")
# check_result("NYT-people","freebase")

# check_result("iimb000","iimb001")
check_result("imdb","dbpedia")

# check_result("dblpscholar","scholar")
# check_result("dblpacm","acm")
# check_result("abt","buy")
# check_result("amazon","googleproducts")

# spliter("diseasome")
# spliter("sider")
# spliter("drugbank")
# spliter("linkedct")
# spliter("dailymed")

# puts fmeasure(1,0.01)

# puts "S* lee".downcase.jarowinkler_similar("stanf lee".downcase)
# puts "Aminohippurate".downcase.jarowinkler_similar("aminohippuric acid")
# # puts mean_and_standard_deviation([1,2,3,1,1,2,1])[0]
#
# puts [12,34].max
# solution=[]
# File.open("/Users/samuraraujo/tmp/alignment/dailymed-tcm-modified.txt", 'r').each{ |line|
# solution << line.rstrip
# }
# solution.uniq!
# puts solution

# puts median([0.99,0.67])
# puts [30,5,6,31,33,32,7,1,2,3,8,15,16,17,9,27,23,24,26,18,19,20,21,4,29,28,10,11,12,14,22].sort
# puts [4,25,26,12,16,17,18,19,27,10,11,15,5,6,28,30,29,7,1,2,3,8,9,13,14,15,7,24,20,21,23,].uniq.sort

# puts " fdsds".size

# puts "teste"stan lee
# puts "lee, s.".split(" ").map{|x| x.gsub(/\W/," ")  }
# puts samur_string_matching("Fire, D.".keyword_normalization, "Dragons: Fire and Ice".keyword_normalization)
# puts samur_string_matching("gs medical corporation".keyword_normalization, "re medical corporation".keyword_normalization)
# puts samur_string_matching("Seacoast Banking".keyword_normalization, "bank".keyword_normalization)
# puts samur_string_matching("Seacoast Banking".keyword_normalization, "bank".keyword_normalization)
# puts samur_string_matching("ctrip com".keyword_normalization, "ctrip".keyword_normalization)
$stopwords=["gold" ,"and" ,"silver" ,"corporation","theather","energy" ]
# puts advanced_string_matching( "paramount gold and silver corporation","paramount theather")
# puts advanced_string_matching( "cms energy corporation","cms energy")
# puts "tulsa talons".jarowinkler_similar("tulsa okla")
# puts advanced_string_matching( "tulsa oklahoma","tulsa okla")
# puts advanced_string_matching( "quebec province","quebec")
# puts advanced_string_matching("john s f", "john salton eles")

