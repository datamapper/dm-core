require File.join(File.dirname(__FILE__), 'support', 'inflector')

module DataMapper
  
  def self.repository
    :default
  end
  
  module Resource
    
    def self.included(target)
      target.send(:extend, ClassMethods)
      target.instance_variable_set("@resource_names", Hash.new { |h,k| h[k] = Inflector.tableize(target.name) })
      target.instance_variable_set("@properties", Hash.new { |h,k| h[k] = [] })
    end
    
    module ClassMethods
      
      def resource_name(repository_name)
        @resource_names[repository_name]
      end
      
      def resource_names
        @resource_names
      end
      
      def property(name, type, options = {})
        properties(DataMapper.repository) << Property.new(name, type, options)
      end
      
      def properties(repository_name)
        if repository_name == :default
          @properties[repository_name]
        else
          @properties[:default].map do |property|
            @properties[repository_name].detect { |override| property.name == override.name } || property
          end
        end
      end
      
      class Property
        def initialize(name, type, options)
          @name, @type, @options = name, type, options
        end
        
        def name
          @name
        end
      end
      
    end
  end
end