module DataMapper
  
  module Attributes
    
    def self.included(klass)
      klass.const_set('ATTRIBUTES', Set.new) unless klass.const_defined?('ATTRIBUTES')
    end
    
    def attributes
      __get_attributes(true)
    end
    
    # Mass-assign mapped fields.
    def attributes=(values_hash)
      __set_attributes(values_hash, true)
    end
    
    private
    
    def __method_defined?(name, public_only = true)
      if public_only
        self.class.public_method_defined?(name)
      else
        self.class.private_method_defined?(name) || 
          self.class.protected_method_defined?(name) ||
          self.class.public_method_defined?(name)
      end
    end
    
    def __get_attributes(public_only)
      pairs = {}
      
      self.class::ATTRIBUTES.each do |name|
        getter = if __method_defined?(name, public_only)
          name
        elsif __method_defined?(name.to_s.ensure_ends_with('?'), public_only)
          name.to_s.ensure_ends_with('?')
        else
          nil         
        end
        
        if getter
          value = send(getter)
          pairs[name] = value.is_a?(Class) ? value.to_s : value
        end
      end
      
      pairs
    end
    
    def __set_attributes(values_hash, public_only)
      values_hash.each_pair do |k,v|
        setter_name = k.to_s.sub(/\?$/, '').ensure_ends_with('=')
        if __method_defined?(setter_name, public_only)
          send(setter_name, v)
        end
      end
      
      self
    end
        
    # return all attributes, regardless of their visibility
    def private_attributes
      __get_attributes(false)
    end

    # private method for setting any/all attribute values, regardless of visibility
    def private_attributes=(values_hash)
      __set_attributes(values_hash, false)
    end
  end
  
end