require File.join(File.dirname(__FILE__), 'support', 'inflector')
require File.join(File.dirname(__FILE__), 'property_set')
require File.join(File.dirname(__FILE__), 'property')
require File.join(File.dirname(__FILE__), 'repository')

module DataMapper
  
  module Resource
    
    def self.included(target)
      target.send(:extend, ClassMethods)
      target.instance_variable_set("@resource_names", Hash.new { |h,k| h[k] = Inflector.tableize(target.name) })
      target.instance_variable_set("@properties", Hash.new { |h,k| h[k] = (k == :default ? [] : h[:default].dup) })
    end
    
    def self.===(other)
      other.ancestors.include?(Resource)
    end
    
    module ClassMethods
      
      def resource_name(repository_name)
        @resource_names[repository_name]
      end
      
      def resource_names
        @resource_names
      end
      
      def property(name, type, options = {})
        property = properties(repository.name) << Property.new(self, name, type, options)
        
        # Add property to the other mappings as well if this is for the default repository.
        if repository.name == :default
          @properties.each_pair do |repository_name, properties|
            next if repository_name == :default
            properties << property
          end          
        end
        
        property
      end
      # +has+ is nice. Inspired by the Traits gem. Declared as the alias to avoid conflicts.
      alias has property
      
      def properties(repository_name)
        @properties[repository_name]
      end
    
    end
  end
end