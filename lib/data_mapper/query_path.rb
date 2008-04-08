module DataMapper
  class QueryPath
  
    attr_reader :relationships, :model, :property
  
    def initialize(relationships, model_name ,property_name=nil)
      @relationships = relationships
      @model         = DataMapper::Inflection.classify(model_name.to_s).to_class
      @property      = @model.properties(@model.repository.name)[model_name] if property_name
    end
    
   alias_method :_method_missing, :method_missing  
   
   def method_missing(method, *args)
     if @model.relationships.has_key?(method)
       relations = []
       relations.concat(@relationships)
       relations << @model.relationships[method]
       return DataMapper::QueryPath.new(relations,method)
     end
     
     if @model.properties(@model.repository.name)[method]
       @property = @model.properties(@model.repository.name)[method]
       return self
     end
     
     _method_missing(method,args)
   end  
    
   # duck type the QueryPath to act like a DM::Property      
   def field
     @property ? @property.field : nil
   end
         
  end # class QueryPath
end # module DataMapper
