# Parser for SPARQL XML result set.
class SparqlResultParser
  attr_reader :result
  
  def initialize(select_clauses=nil)
    @ignorevar=false 
    @result = []
     @vars = [] 
    if select_clauses != nil    && select_clauses.size>0    
      @ignorevar=true
      @vars = select_clauses.map{|x| x.to_s}
      
    end
    @current_type = nil
  end
  
  def tag_start(name, attrs)
    case name
      when 'variable'
      @vars << attrs['name'] if @ignorevar ==false      
      when 'result'
      @current_result = []
      when 'binding'
      @index = @vars.index(attrs['name'])
       
      when 'bnode', 'literal', 'typed-literal', 'uri','boolean'
      @current_type = name
    end
  end
  
  def tag_end(name)
    if name == "result"
      @result << @current_result  
    elsif name == 'bnode' || name == 'literal' || name == 'typed-literal' || name == 'uri'  || name == 'boolean'
      @current_type = nil
    elsif name == "sparql"
    end
  end
  
  def text(text)
    if !@current_type.nil?
      if @current_type == 'boolean'
        @result <<  (text)
      else
        @current_result[@index] = create_node(@current_type, text)  
      end
      
    end
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
  
  def method_missing (*args)
  end
end
