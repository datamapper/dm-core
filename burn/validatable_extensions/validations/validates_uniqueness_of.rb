module Validatable
  class ValidatesUniquenessOf < ValidationBase
    option :scope, :allow_nil, :case_sensitive

    def message(instance)
      super || '%s has already been taken'.t(humanized_attribute)
    end
    
    def case_sensitive?
      case_sensitive
    end
    
    def valid?(instance)
      value = instance.send(self.attribute)
      return true if allow_nil && value.nil?
      
      finder_options = if case_sensitive?
        { self.attribute => value }
      else
        { self.attribute.like => value }
      end
      
      if scope 
        if scope.kind_of?(Array) # if scope is larger than just one property, check them all
          scope.each do |scope_property|
            scope_value = instance.send(scope_property)
            finder_options.merge! scope_property => scope_value
          end
        else
          scope_value = instance.send(scope)
          finder_options.merge! scope => scope_value
        end
      end
      
      finder_options.merge!({ instance.database_context.table(instance.class).key.name.not => instance.key }) unless instance.new_record?
      instance.database_context.first(instance.class, finder_options).nil?
    end  
  end
  
end
