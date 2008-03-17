require File.join(File.dirname(__FILE__), 'support', 'inflector')
require File.join(File.dirname(__FILE__), 'support', 'string')
require File.join(File.dirname(__FILE__), 'property_set')
require File.join(File.dirname(__FILE__), 'property')
require File.join(File.dirname(__FILE__), 'repository')

module DataMapper
  
  module Resource
    
    def self.included(target)
      target.send(:extend, ClassMethods)
      target.instance_variable_set("@resource_names", Hash.new { |h,k| h[k] = repository(k).adapter.resource_naming_convention.call(target.name) })
      target.instance_variable_set("@properties", Hash.new { |h,k| h[k] = (k == :default ? PropertySet.new : h[:default].dup) })
    end
    
    def repository
      @loaded_set ? @loaded_set.repository : self.class.repository
    end
    
    def loaded_set
      @loaded_set
    end
    
    def loaded_set=(value)
      @loaded_set = value
    end
    
    def readonly!
      @readonly = true
    end
    
    def readonly?
      @readonly == true
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
      if self.class.properties(self.class.default_repository_name).empty?
        raise IncompleteResourceError.new("Resources must have at least one property to be initialized.")
      end
    end
    
    def self.===(other)
      other.is_a?(Module) && other.ancestors.include?(Resource)
    end
    
    def attributes
      pairs = {}
      
      self.class.properties(repository.name).each do |property|
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
      
      self.class.properties(repository.name).each do |property|
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

#     def attribute_get(property_name)
#       property = self.class.properties(repository.name)[property_name.to_sym]
#       if property.lazy? && !property.loaded?
#         lazy_load!(property_name)
#       end
#       property.instance_variable_get(:@value)
#     end
# 
#     def attribute_set(property_name, value)
#       property = self.class.properties(repository.name).name(property_name.to_sym)
# 
# =begin
#       We've got three options here to handle dirty tracking
# 
#       1) Simply as soon as the property is loaded then any change results in the property being dirty
#       property.dirty = property.loaded?
#       
#       2) We can store the original value of the field as soon as make a change after it is loaded
#       if !property.dirty? && property.loaded?
#         property.instance_variable_set(:@original_value, property.instance_variable_get(:@value))
#         property.dirty = true
#       end
# 
#       3) We can do full tracking where the value is tracked and if changed and then reverted the dirty flag is cleared
#       if property.loaded?
#         property.instance_variable_set(:original_value, property.instance_variable_get(:value)) unless property.original_value_set?
#         property.dirty = !(property.instance_variable_get(:@original_value) == value)
#       end
# =end
#       
#       property.dirty = property.loaded?
#       property.instance_variable_set(:@value, value)
#       property.loaded = true
#     end

    public
    
    module ClassMethods
      
      def repository
        DataMapper::repository(default_repository_name)
      end
      
      def default_repository_name
        :default
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
        if repository.name == default_repository_name
          @properties.each_pair do |repository_name, properties|
            next if repository_name == default_repository_name
            properties << property
          end          
        end
        
        property
      end
      
      def properties(repository_name)
        @properties[repository_name]
      end
      
      def key(repository_name)
        @properties[repository_name].select { |property| property.key? }
      end
      
      def inheritance_property(repository_name)
        @properties[repository_name].detect { |property| property.type == Class }
      end
    end
  end
end