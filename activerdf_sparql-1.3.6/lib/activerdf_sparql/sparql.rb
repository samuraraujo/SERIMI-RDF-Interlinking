require 'net/https'
 require 'net/http'
require 'queryengine/query2sparql'
require 'open-uri'
require 'cgi'
require 'rexml/document'
require "#{File.dirname(__FILE__)}/sparql_result_parser"

# SPARQL adapter
class SparqlAdapter < ActiveRdfAdapter
  $activerdflog.info "loading SPARQL adapter"
  ConnectionPool.register_adapter(:sparql, self)  
  attr_reader :engine
  attr_reader :caching , :url #,:raw
  def reset_cache()     
    @sparql_cache = {}
  end
  #  def SparqlAdapter.get_cache
  #    return @sparql_cache
  #  end
  
  # Instantiate the connection with the SPARQL Endpoint.
  # available parameters:
  # * :url => url: endpoint location e.g. "http://m3pe.org:8080/repositories/test-people"
  # * :results => one of :xml, :json, :sparql_xml
  # * :request_method => :get (default) or :post
  # * :timeout => timeout in seconds to wait for endpoint response
  # * :auth => [user, pass]
  def initialize(params = {})	
    super() 
    @sparql_cache = {}
    @reads = true
    @writes = false
    @title =params[:title] 
    @url = params[:url] || ''
    @caching = params[:caching] || false
    #    @preprocess = params[:preprocess] || false
    #    @raw = params[:raw] || false
    
    @timeout = params[:timeout] || 100
    @auth = params[:auth] || nil
    
    @result_format = params[:results] || :json
    raise ActiveRdfError, "Result format unsupported" unless [:xml, :json, :sparql_xml].include? @result_format
    
    
    @engine = params[:engine]
    if @engine == nil
      response = Net::HTTP.get_response(URI.parse(@url))    
      if  response['server'].to_s.downcase.index('virtuoso') != nil  
        @engine = :virtuoso 
      else
        @engine = :sesame2 
      end
    end 
    raise ActiveRdfError, "SPARQL engine unsupported" unless [:yars2, :sesame2, :joseki, :virtuoso].include? @engine
    
    @request_method = params[:request_method] || :get
    raise ActiveRdfError, "Request method unsupported" unless [:get,:post].include? @request_method
  end
  
  def size
    query(Query.new.select(:s,:p,:o).where(:s,:p,:o)).size
  end
  
  # query datastore with query string (SPARQL), returns array with query results
  # may be called with a block
  def query(query, &block)    
    puts "Querying ...#{@title}"
    qs = Query2SPARQL.translate(query,@engine)   
    
    puts qs.to_s  
    if query.insert? || query.delete?     
      reset_cache()
      return execute_sparql_query(qs, header(query), query.select_clauses, &block)
    end
    
    if @caching 
      if is_into_cache(qs) 
        $activerdflog.debug "cache hit for query #{qs}"
        
        resp = query_cache(qs)
        
        return  resp
      end
    end    
    
    result = execute_sparql_query(qs, header(query), query.select_clauses, &block)
    add_to_cache(qs, result) if @caching
    result = [] if result == "timeout"
    
    return result
  end
  
  
  # do the real work of executing the sparql query
  def execute_sparql_query(qs, header=nil, select_clauses=nil, &block)
    header = header(nil) if header.nil?
    
    #    puts select_clauses
    # querying sparql endpoint
    require 'timeout'
    response = ''
    url =''
    begin 
      case @request_method
        when :get
        # encoding query string in URL
        if @url.index('?') == nil
          url = "#@url?query=#{CGI.escape(qs)}"        
        else
          url = "#@url&query=#{CGI.escape(qs)}"          
        end
        #puts url
        $activerdflog.debug "GET #{url}"        
        timeout(@timeout) do          
          #             puts url
          open(url, header) do |f|            
            response = f.read   
            #                          puts response
          end
        end
        when :post
        puts 'Via POST'
        $activerdflog.debug "POST #@url with #{qs}"
        t = URI.parse(@url)
       # puts t
        t =  t.query
       # puts t
        if t != nil
         
          param = CGI::parse(t)
          param["query"]=qs
          
          response = Net::HTTP.post_form(URI.parse(@url),param).body
         
        else
          response = Net::HTTP.post_form(URI.parse(@url),{'query'=>qs}).body
        end
        
        
        
      end
      #      puts response
    rescue Timeout::Error
      raise ActiveRdfError, "timeout on SPARQL endpoint. <br><br><b>URI accessed:</b> " + url
      return "timeout"
    rescue OpenURI::HTTPError => e
      raise ActiveRdfError, "could not query SPARQL endpoint, server said: #{e} . <br><br><b>URI accessed:</b> " + url
      return []
      #    rescue Errno::ECONNREFUSED
    rescue Exception => e
      puts e.backtrace
      raise ActiveRdfError, "connection refused on SPARQL endpoint #@url"
      return []
    end
    # puts response
    #    results =  preprocess(results) if @preprocess
    #    return results if @raw  
    # we parse content depending on the result format    
    results = case @result_format
      when :json 
      parse_json(response)
      when :xml, :sparql_xml
      parse_xml(response,select_clauses)
    end
    
    if block_given?
      results.each do |*clauses|
        yield(*clauses)
      end
    else      
      results
    end
  end 
  def close
    ConnectionPool.remove_data_source(self)
  end	
  protected
  def add_to_cache(query_string, result)
    if result.nil? or result.empty?
      @sparql_cache.store(query_string, [])
    else
      if result == "timeout"
        @sparql_cache.store(query_string, [])
      else 
        $activerdflog.debug "adding to sparql cache - query: #{query_string}"
        @sparql_cache.store(query_string, result) 
      end
    end
  end 
  def is_into_cache(query_string)
    @sparql_cache.include?(query_string)      
  end
  def query_cache(query_string)         
    return @sparql_cache.fetch(query_string)    
  end
  
  # constructs correct HTTP header for selected query-result format
  def header(query)
    header = case @result_format
      when :json
      { 'accept' => 'application/sparql-results+json' }
      when :xml
      { 'accept' => 'application/rdf+xml' }
      when :sparql_xml
      { 'accept' => 'application/sparql-results+xml' }
    end
    if @auth
      header.merge( :http_basic_authentication => @auth )
    else
      header
    end
  end
  
  # parse json query results into array
  def parse_json(s)
    # this will try to first load json with the native c extensions, 
    # and if this fails json_pure will be loaded
    require 'json'
    
    parsed_object = JSON.parse(s)
    return [] if parsed_object.nil?
    
    results = []    
    vars = parsed_object['head']['vars']
    objects = parsed_object['results']['bindings']
    
    objects.each do |obj|
      result = []
      vars.each do |v|
        result << create_node( obj[v]['type'], obj[v]['value'])
      end
      results << result
    end
    
    results
  end
  
  # parse xml stream result into array
  def parse_xml(s,select_clauses=nil)    
    parser = SparqlResultParser.new(select_clauses)
    REXML::Document.parse_stream(s, parser) 
    parser.result
  end  
  # create ruby objects for each RDF node
  def create_node(type, value)
    case type
      when 'uri'
      RDFS::Resource.new(value)
      when 'bnode'
      BNode.new(value)
      when 'literal','typed-literal'
      value.to_s
    end
  end   
end
