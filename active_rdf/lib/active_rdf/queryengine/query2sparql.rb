 

# TODO: support limit and offset

# Translates abstract query into SPARQL that can be executed on SPARQL-compliant
# data source.
class Query2SPARQL
  Engines_With_Keyword = [:yars2, :virtuoso,:sesame2] 
  
  def self.translate(query, engine=nil)
    return query.sparql_query if query.sparql_query != nil 
    str = ""
    # puts query.insert?      
    if query.select?      
      distinct = query.distinct? ? "DISTINCT " : ""
      select_clauses = query.select_clauses.collect{|s| construct_clause(s)}
      str << "SELECT #{distinct}#{select_clauses.join(' ')} "      
      str << "WHERE { #{where_clauses(query)} #{optional_clauses(query)} #{filter_clauses(query)} #{keywords_clauses(query,engine)}} "
      str << "ORDER BY #{query.sort_clauses} " unless query.sort_clauses.empty?
      str << "LIMIT #{query.limits} " if query.limits
      str << "OFFSET #{query.offsets} " if query.offsets
    elsif query.ask?
      str << "ASK { #{where_clauses(query)} } "
    elsif query.insert?      
      
      str << "INSERT INTO #{insert_clauses(query)} "
    elsif query.delete?      
       tmp = delete_clauses(query)
      str << "DELETE FROM GRAPH #{tmp} FROM #{tmp} "     
     
    end    
    
    return str
  end
  # concatenate filters in query
  def self.optional_clauses(query)
    object = nil
    count = 0
    optional_clauses = query.optional_clauses.collect do |s,p,o,c|
      object = nil
      #replace a where clause by filter in case of String as object.    
      if o.instance_of? String
        object = o       
        count=count+1
        o = 'a' + count.to_s
        o=o.to_sym()
      end
      
      # does there where clause use a context ? 
      if c.nil?         
        where = "OPTIONAL {"
        where = where +  [s,p,o].collect {|term| construct_clause(term) }.join(' ')        
        where = where + " FILTER(str(?#{o}) = '#{object}')  " unless object == nil
        where = where + " } "
        
        where
      else
        "GRAPH #{construct_clause(c)} { #{construct_clause(s)} #{construct_clause(p)} #{construct_clause(o)} }"
      end         
    end    
    "#{optional_clauses.join(' . ')} ." unless optional_clauses.empty?       
  end
  # concatenate filters in query
  def self.filter_clauses(query)
    "FILTER (#{query.filter_clauses.join(" && ")})" unless query.filter_clauses.empty?
  end
  #build keywords
  def self.keywords_clauses(query,engine=nil)
    if query.keyword?           
      filters= Array.new
      query.keywords.each do |term, keyword|
        
        if engine == :virtuoso
          filters << "bif:contains (?#{term}, '\"#{keyword}\"')"    
        else
          filters << "regex(str(?#{term}),'#{keyword}','i')"        
        end           
      end      
      filters = " FILTER (#{filters.join(" || ")})" unless filters.empty?     
      filters 
    end 
  end
  # concatenate each where clause using space (e.g. 's p o')
  # and concatenate the clauses using dot, e.g. 's p o . s2 p2 o2 .'
  def self.where_clauses(query)   
    object = nil
    count = 0
    where_clauses = query.where_clauses.collect do |s,p,o,c|
      object = nil
      #replace a where clause by filter in case of String as object.    
      if o.instance_of? String
        object = o       
        count=count+1
        o = 'o' + count.to_s
        o=o.to_sym()
      end
      # does there where clause use a context ? 
      if c.nil?
        where =  [s,p,o].collect {|term| construct_clause(term) }.join(' ')        
        where = where + " FILTER(str(?#{o}) = '#{object}') " unless object == nil      
        where
      else
  		  "GRAPH #{construct_clause(c)} { #{construct_clause(s)} #{construct_clause(p)} #{construct_clause(o)} }"
      end
    end    
    "#{where_clauses.join(' . ')} ." unless where_clauses.empty?    
  end
  
  def self.insert_clauses(query)       
    s= query.insert_clauses[0]
    p= query.insert_clauses[1]
    o= query.insert_clauses[2]
    c= query.insert_clauses[3]
    insert_clauses =  " GRAPH #{construct_clause(c)} { #{construct_clause(s)} #{construct_clause(p)} #{construct_clause(o)} }"      
    
    # puts insert_clauses
#    "#{insert_clauses.join('  ')} " unless insert_clauses.empty?    
  end
  def self.delete_clauses(query)      
    s= query.delete_clauses[0]
    p= query.delete_clauses[1]
    o= query.delete_clauses[2]
    c= query.delete_clauses[3]
    delete_clauses =  "  #{construct_clause(c)} { #{construct_clause(s)} #{construct_clause(p)} #{construct_clause(o)} }"      
    
    # puts insert_clauses
#    "#{delete_clauses.join('  ')} " unless insert_clauses.empty?    
  end
  def self.construct_clause(term)   
   
    if term.is_a?(Symbol)
      "?#{term}"
    else
      term.to_ntriple
    end
  end
  def self.insert(query)
    
    
  end
  def self.sparql_engine
    sparql_adapters = ConnectionPool.read_adapters.select{|adp| adp.is_a? SparqlAdapter}
    engines = sparql_adapters.collect {|adp| adp.engine}.uniq
    
    unless engines.all?{|eng| Engines_With_Keyword.include?(eng)}
      raise ActiveRdfError, "one or more of the specified SPARQL engines do not support keyword queries" 
    end
    
    if engines.size > 1
      raise ActiveRdfError, "we currently only support keyword queries for one type of SPARQL engine (e.g. Yars2 or Virtuoso) at a time"
    end
    
    return engines.first
  end
  
  def self.keyword_predicate
    case sparql_engine
      when :yars, :yars2
      RDFS::Resource.new("http://sw.deri.org/2004/06/yars#keyword")
      when :virtuoso
      VirtuosoBIF.new("bif:contains")
    else
      raise ActiveRdfError, "default SPARQL does not support keyword queries, remove the keyword clause or specify the type of SPARQL engine used"
    end
  end
  
  private_class_method :where_clauses, :construct_clause, :keyword_predicate, :sparql_engine
end

# treat virtuoso built-ins slightly different: they are URIs but without <> 
# surrounding them
class VirtuosoBIF < RDFS::Resource
  def to_s
    uri
  end
end
