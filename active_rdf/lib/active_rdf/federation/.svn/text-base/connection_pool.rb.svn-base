require 'active_rdf'

# Maintains pool of adapter instances that are connected to datasources. Returns 
# right adapter for a given datasource, by either reusing an
# existing adapter-instance or creating new a adapter-instance.

class ConnectionPool
  class << self
    attr_accessor :write_adapter
    # sets automatic flushing of data from adapters to original datasources 
    # (e.g. redland on-file database). If disabled, changes to an adapter are 
    # not written back into the original source: you need to invoke 
    # ConnectionPool.flush manually
    bool_accessor :auto_flush
  end
  # pool of all adapters
  @@adapter_pool = Array.new
  
  @@void = Hash.new
  
  # pool of connection parameters to all adapter
  @@adapter_parameters = Array.new
  
  # currently active write-adapter (we can only write to one at a time)
  self.write_adapter = nil
  
  # default setting for auto_flush
  self.auto_flush = true
  
  # adapters-classes known to the pool, registered by the adapter-class
  # itself using register_adapter method, used to select new
  # adapter-instance for requested connection type
  @@registered_adapter_types = Hash.new
  
  # clears the pool: removes all registered data sources
  def ConnectionPool.clear
    $activerdflog.info "ConnectionPool: clear called"
    @@adapter_pool = []
    @@adapter_parameters = []
    @@void=Hash.new
    self.write_adapter = nil
  end
  def ConnectionPool.void
    @@void
  end
  def ConnectionPool.adapters
    @@adapter_pool.dup
  end
  def ConnectionPool.get_adapter(name)    
    adapter = @@adapter_pool.select {|adapter| 
      adapter.title == name
    }
    adapter.first()
  end
  # flushes all openstanding changes into the original datasource.
  def ConnectionPool.flush
    write_adapter.flush
  end
  
  def ConnectionPool.adapter_types
    @@registered_adapter_types.keys
  end
  
  # returns the set of currently registered read-access datasources
  def ConnectionPool.read_adapters
    @@adapter_pool.select {|adapter| 
     (adapter.reads? &&  adapter.enabled?)
    }
  end
  def ConnectionPool.write_adapters    
    @@adapter_pool.select {|x| (x.writes? && x.enabled?) }
  end
  
  # returns adapter-instance for given parameters (either existing or new)
  def ConnectionPool.add_data_source(connection_params )
    $activerdflog.info "ConnectionPool: add_data_source with params: #{connection_params.inspect}"
    
    #Verifies if the adapter with same uri was added before.
    adapter  = ConnectionPool.find_by_uri(connection_params[:url])
  
    return adapter if adapter != nil
    # either get the adapter-instance from the pool
    # or create new one (and add it to the pool)
    index = @@adapter_parameters.index(connection_params)    
    if index.nil?
      # adapter not in the pool yet: create it,
      # register its connection parameters in parameters-array
      # and add it to the pool (at same index-position as parameters)
      $activerdflog.debug("Create a new adapter for parameters #{connection_params.inspect}")
      adapter = create_adapter(connection_params)
      # this is necessary because activerdf search in the order repositories were added
      if adapter.title == 'INTERNAL'         
        @@adapter_parameters << connection_params
        @@adapter_pool << adapter
      else
        @@adapter_parameters.insert(0,connection_params)
        @@adapter_pool.insert(0,adapter)
      end
    else
      # if adapter parametrs registered already,
      # then adapter must be in the pool, at the same index-position as its parameters
      $activerdflog.debug("Reusing existing adapter")
      adapter = @@adapter_pool[index]
    end    
    # sets the adapter as current write-source if it can write
    self.write_adapter = adapter if adapter.writes?
    begin
      void_source =  adapter.query(Query.new.select(:o).where(:s,RDFS::Resource.new('<http://xmlns.com/foaf/0.1/homepage>') ,:o).where(:s,RDF::type,RDFS::Resource.new('<http://rdfs.org/ns/void#Dataset>'))).uniq
      @@void[void_source.to_s.gsub(/>/,'').gsub(/</,'')]=adapter if void_source != nil
    rescue Exception => e
      remove_data_source(adapter)
    end    
    return adapter
  end
  
  # remove one adapter from activerdf
  def ConnectionPool.remove_data_source(adapter)
    RDFS::Resource.reset_cache() 
    
    $activerdflog.info "ConnectionPool: remove_data_source with params: #{adapter.to_s}"
    
    index = @@adapter_pool.index(adapter)
    
    # remove_data_source mit be called repeatedly, e.g because the adapter object is stale
    unless index.nil?
      @@adapter_parameters.delete_at(index)
      @@adapter_pool.delete_at(index)
      #      if self.write_adapters.empty?
      #        self.write_adapter = nil
      #      else
      #        self.write_adapter = self.write_adapters.first
      #      end
      
    end
    
  end
  
  # sets adapter-instance for connection parameters (if you want to re-enable an existing adapter)
  def ConnectionPool.set_data_source(adapter, connection_params = {})
    index = @@adapter_parameters.index(connection_params)
    if index.nil?
      @@adapter_parameters << connection_params
      @@adapter_pool << adapter
    else
      @@adapter_pool[index] = adapter
    end
    self.write_adapter = adapter if adapter.writes?
    adapter
  end
  
  # aliasing add_data_source as add
  # (code bit more complicad since they are class methods)
  class << self
    alias add add_data_source
  end
  #find an sparql adapter by its uri
  def ConnectionPool.find_by_uri(uri)
    
    @@adapter_pool.each {|x|
      if x.instance_of? SparqlAdapter
        
        if x.url == uri
          return x
        end
      end
    }
    return nil
    
  end
  # adapter-types can register themselves with connection pool by
  # indicating which adapter-type they are
  def ConnectionPool.register_adapter(type, klass)
    $activerdflog.debug "ConnectionPool: registering adapter of type #{type} for class #{klass}"
    @@registered_adapter_types[type] = klass
  end
  
  # create new adapter from connection parameters
  def ConnectionPool.create_adapter connection_params
    # lookup registered adapter klass
    
    klass = @@registered_adapter_types[connection_params[:type]]
    
    # raise error if adapter type unknown
    raise(ActiveRdfError, "unknown adapter type #{connection_params[:type]}") if klass.nil?
    
    # create new adapter-instance
    klass.send(:new,connection_params)
    
  end
  
#  private_class_method :create_adapter
end
