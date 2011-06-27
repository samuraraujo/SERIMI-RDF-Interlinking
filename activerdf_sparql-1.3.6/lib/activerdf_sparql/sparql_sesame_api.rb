require 'rjb' unless RUBY_PLATFORM =~ /java/
 if RUBY_PLATFORM =~ /java/
   require "java"
   
 end
 
# SPARQL adapter

class SparqlSesameApiAdapter < ActiveRdfAdapter

  # include Java if RUBY_PLATFORM =~ /java/

  $activerdflog.info "loading SPARQL SESAME API adapter"

  ConnectionPool.register_adapter(:sparql_sesame_api, self)
  attr_reader :caching, :bridge
  def reset_cache()
    @sparql_cache = {}
  end
  #  def SparqlAdapter.get_cache
  #    return @sparql_cache
  #  end

  # Instantiate the connection with the SPARQL Endpoint.
  # available parameters:
  # * :results => :sparql_xml
  def initialize(params = {})
    super()
    @sparql_cache = {}
    @reads = true
    @writes = true
    @caching = params[:caching] || false
    @result_format = :sparql_xml
    @repository = params[:repository]
    @sesamedir =params[:dir]
    @title =params[:title]

    puts "INITIALING ... " + @title
    puts @sesamedir
    sesame_jars=''
    dir ="#{File.dirname(__FILE__)}/java/"
    Dir.foreach(dir) {|x|
      sesame_jars += dir  + x +  File::PATH_SEPARATOR unless x.index('jar') == nil
    }
    begin
      vmargs = [ '-Xms256m', '-Xmx1024m' ]
      vmargs << ('-Dinfo.aduna.platform.appdata.basedir=' + @sesamedir)
      vmargs << ('-J-Dinfo.aduna.platform.appdata.basedir=' + @sesamedir)

      if RUBY_PLATFORM =~ /java/
        sesame_jars = sesame_jars.split(File::PATH_SEPARATOR)
        sesame_jars.each{ |v| require v }
      else
      Rjb::load sesame_jars , vmargs
      end

    rescue => ex
      raise ex, "Could not load Java Virtual Machine. Please, check if your JAVA_HOME environment variable is pointing to a valid JDK (1.4+). #{ex}"

    rescue LoadError => ex
      raise ex, "Could not load RJB. Please, install it properly with the command 'gem install rjb'"
    end
  # puts "PLATAFORM " + RUBY_PLATFORM + (RUBY_PLATFORM =~ /java/).to_s
    if RUBY_PLATFORM =~ /java/
      
       include_class 'br.tecweb.explorator.SesameApiRubyAdapter'
      @bridge = SesameApiRubyAdapter.new(@repository)
      
    else
      @bridge = Rjb::import('br.tecweb.explorator.SesameApiRubyAdapter').new(@repository)
    end
  end

  def size
    query(Query.new.select(:s,:p,:o).where(:s,:p,:o)).size
  end

  # query datastore with query string (SPARQL), returns array with query results
  # may be called with a block
  def query(query, &block)
    puts "Quering .. #{@title} "
    qs = Query2SPARQL.translate(query)

    if !(@title.include?'INTERNAL' and qs.to_s.include? "http://www.tecweb.inf.puc-rio.br")
      if @caching
        if is_into_cache(qs)
          $activerdflog.debug "cache hit for query #{qs}"
          return  query_cache(qs)
        end
      end
    end

    result = execute_sparql_query(qs, &block)
    #   puts result
    add_to_cache(qs, result) if @caching
    result = [] if result == "timeout"
    puts @title
    puts qs.to_s
    return result
  end

  # do the real work of executing the sparql query
  def execute_sparql_query(qs, header=nil, &block)
    response = ''
    begin
      response = @bridge.query(qs.to_s)
      #        puts response
    rescue
      raise ActiveRdfError, "JAVA BRIDGE ERRO ON SPARQL ADAPTER"
      return "timeout"
    end
    # we parse content depending on the result format
    results =  parse_xml(response)

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

  # adds triple(s,p,o) to datastore
  # s,p must be resources, o can be primitive data or resource
  def add(s,p,o,c=nil)

    # check illegal input
    raise(ActiveRdfError, "adding non-resource #{s} while adding (#{s},#{p},#{o},#{c})") unless s.respond_to?(:uri)
    raise(ActiveRdfError, "adding non-resource #{p} while adding (#{s},#{p},#{o},#{c})") unless p.respond_to?(:uri)
    s = s.to_s if s != nil
    p = p.to_s if p != nil
    o = o.to_s if o != nil
    c = c.to_s if c != nil
    response = @bridge.insert(s,p,o,c)
  end

  def delete(s,p,o,c=nil)

    #    # check illegal input
    #    raise(ActiveRdfError, "deleting non-resource #{s} while adding (#{s},#{p},#{o},#{c})") unless s.respond_to?(:uri)
    #    raise(ActiveRdfError, "deleting non-resource #{p} while adding (#{s},#{p},#{o},#{c})") unless p.respond_to?(:uri)
    #
    quad = [s,p,o,c].collect {|r| r.nil? ? nil : internalise(r) }

    response = @bridge.delete(quad[0],quad[1],quad[2],quad[3])

  end

  # transform triple into internal format <uri> and "literal"
  def internalise(r)
    if r.respond_to?(:uri)
    r.uri
    elsif r.is_a?(Symbol)
    nil
    else
    r.to_s
    end
  end
  private

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
    if @sparql_cache.include?(query_string)
    return @sparql_cache.fetch(query_string)
    else
    return nil
    end
  end

  # parse xml stream result into array
  def parse_xml(s)
    parser = SparqlResultParser.new
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
