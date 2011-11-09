require 'net/http'
require 'uri'



def endpage (uri) 
  response = Net::HTTP.get_response(URI.parse(uri)) 
  if response.code.to_i != 200 
    endpage(response['location'])
  end
  return uri
end

puts endpage "http://dbpedia.org/resource/Chinatown_%28disambiguation%29"
