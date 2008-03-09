require File.join(File.dirname(__FILE__), 'support', 'inflector')
require File.join(File.dirname(__FILE__), 'support', 'string')
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
    
    def context
      @context
    end
    
    def initialize(details = nil) # :nodoc:
      validate_resource!
      
      def initialize(details = nil)
        if details
          initialize_with_attributes(details)
        end
      end
      
      initialize(details)
    end
    
    def initialize_with_attributes(details) # :nodoc:
      case details
      when Hash then self.attributes = details
      when Resource, Struct then self.private_attributes = details.attributes
      # else raise ArgumentError.new("details should be a Hash, Resource or Struct\n\t#{details.inspect}")
      end
    end
    
    def validate_resource! # :nodoc:
      raise IncompleteResourceError.new("Resources must have at least one property to be initialized.") if self.class.properties(repository_name).empty?
    end
    
    def self.===(other)
      other.is_a?(Module) && other.ancestors.include?(Resource)
    end
    
    def repository_name
      DataMapper::repository.name
    end
    
    def attributes
      pairs = {}
      
      self.class.properties(repository_name).each do |property|
        if property.reader_visibility == :public
          pairs[property.name] = send(property.getter)
        end
      end
      
      pairs
    end
    
    # Mass-assign mapped fields.
    def attributes=(values_hash)
      success = true
      
      values_hash.each_pair do |k,v|
        setter = k.to_s.sub(/\?$/, '').ensure_ends_with('=')
        # We check #public_methods and not Class#public_method_defined? to
        # account for singleton methods.
        if public_methods.include?(setter)
          send(setter, v)
        else
          success = false
        end
      end
      
      success
    end
    
    private
    
    def private_attributes
      pairs = {}
      
      self.class.properties(repository_name).each do |property|
        pairs[property.name] = send(property.getter)
      end
      
      pairs
    end
    
    def private_attributes=(values_hash)
      success = true
      
      values_hash.each_pair do |k,v|
        setter = k.to_s.sub(/\?$/, '').ensure_ends_with('=')
        if respond_to?(setter) || private_methods.include?(setter)
          send(setter, v)
        else
          success = false
        end
      end
      
      success
    end
    
    public
    
    module ClassMethods
      
      def context
        DataMapper::context
      end
      
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
      
      def properties(repository_name)
        @properties[repository_name]
      end
      
      def key
        @key = @properties[:default].select { |property| property.key? }
        
        if @key.nil?
          @key = [property(:id, Fixnum, :serial => true)]
        end
        
        def key
          @key
        end
        
        key
      end
    
    end
  end
end