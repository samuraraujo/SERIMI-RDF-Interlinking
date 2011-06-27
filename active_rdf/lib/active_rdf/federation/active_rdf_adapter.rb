 
require 'queryengine/query2sparql'

# Generic superclass of all adapters

class ActiveRdfAdapter
  # indicate if adapter can read and write
  bool_accessor :reads, :writes
  #enable / disable the adapter in the ConnectionPool.
  bool_accessor :enabled   
  #the name used to identify the specific adapter.
  attr_accessor :title , :limit,:url
  def initialize
    @enabled=true
  end 
  # translate a query to its string representation
  def translate(query)
    Query2SPARQL.translate(query)
  end
  def reset_cache()
    
  end
end
