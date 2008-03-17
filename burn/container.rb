require File.join(File.dirname(__FILE__), 'attributes')
require File.join(File.dirname(__FILE__), 'validations')
require File.join(File.dirname(__FILE__), 'associations')
require File.join(File.dirname(__FILE__), 'callbacks')
require File.join(File.dirname(__FILE__), 'dependency_queue')
require File.join(File.dirname(__FILE__), 'support', 'struct')
require File.join(File.dirname(__FILE__), 'persistable')
require File.join(File.dirname(__FILE__), 'is', 'tree')
require File.join(File.dirname(__FILE__), 'persistable')

module DataMapper
  class Container

    include DataMapper::Attributes
    include DataMapper::Associations
    include DataMapper::Validations
    include DataMapper::CallbacksHelper

    include DataMapper::Is::Tree

    include DataMapper::Persistable

    def inherited(klass)
      klass.send(:include, InstanceMethods)
      klass.extend(ClassMethods)

      klass.instance_variable_set('@properties', [])
    end

    module InstanceMethods
      def initialize(details = nil) # :nodoc:
        check_for_properties!
        if details
          initialize_with_attributes(details)
        end
      end

      def initialize_with_attributes(details) # :nodoc:
        case details
        when Hash then self.attributes = details
        when details.respond_to?(:persistent?) then self.private_attributes = details.attributes
        when Struct then self.private_attributes = details.attributes
        end
      end    

      def check_for_properties! # :nodoc:
        raise IncompleteModelDefinitionError.new("Models must have at least one property to be initialized.") if self.class.properties.blank?
      end

      def inspect
        inspected_attributes = attributes.map { |k,v| "@#{k}=#{v.inspect}" }

          instance_variables.each do |name|
          if instance_variable_get(name).kind_of?(Associations::HasManyAssociation)
            inspected_attributes << "#{name}=#{instance_variable_get(name).inspect}"
          end
          end

      "#<%s:0x%x @new_record=%s, %s>" % [self.class.name, (object_id * 2), new_record?, inspected_attributes.join(', ')]
      end

      def loaded_associations
        @loaded_associations || @loaded_associations = []
      end

      def <=>(other)
        keys <=> other.keys
      end

      # Look to ::included for __hash alias
      def hash
        @__hash || @__hash = keys.empty? ? super : keys.hash
      end

      def eql?(other)
        return false unless other.is_a?(self.class) || self.is_a?(other.class)
        comparator = keys.empty? ? :private_attributes : :keys
        send(comparator) == other.send(comparator)
      end

      def ==(other)
        eql?(other)
      end

      # Returns the difference between two objects, in terms of their
      # attributes.
      def ^(other)
        results = {}

        self_attributes, other_attributes = attributes, other.attributes

        self_attributes.each_pair do |k,v|
          other_value = other_attributes[k]
          unless v == other_value
            results[k] = [v, other_value]
          end
        end

        results
      end
    end

    module ClassMethods
      # Adds property accessors for a field that you'd like to be able to
      # modify.  The DataMapper doesn't
      # use the table schema to infer accessors, you must explicity call
      # #property to add field accessors
      # to your model. 
      #
      # Can accept an unlimited amount of property names. Optionally, you may
      # pass the property names as an 
      # array.
      #
      # For more documentation, see Property.
      #
      # EXAMPLE:
      #   class CellProvider
      #     property :name, :string
      #     property :rating_number, :rating_percent, :integer # will create two properties with same type and text
      #     property [:bill_to, :ship_to, :mail_to], :text, :lazy => false # will create three properties all with same type and text
      #   end
      #
      #   att = CellProvider.new(:name => 'AT&T')
      #   att.rating = 3
      #   puts att.name, att.rating
      #
      #   => AT&T
      #   => 3
      #
      # OPTIONS:
      #   * <tt>lazy</tt>: Lazy load the specified property (:lazy => true). False by default.
      #   * <tt>accessor</tt>: Set method visibility for the property accessors. Affects both
      #   reader and writer. Allowable values are :public, :protected, :private. Defaults to
      #   :public
      #   * <tt>reader</tt>: Like the accessor option but affects only the property reader.
      #   * <tt>writer</tt>: Like the accessor option but affects only the property writer.
      #   * <tt>protected</tt>: Alias for :reader => :public, :writer => :protected
      #   * <tt>private</tt>: Alias for :reader => :public, :writer => :private
      def property(*columns_and_options)        
        columns, options = columns_and_options.partition {|item| not item.is_a?(Hash)}
        options = (options.empty? ? {} : options[0])
        type = columns.pop
      
        @properties ||= []
        new_properties = []
      
        columns.flatten.each do |name|
          property = DataMapper::Property.new(self, name, type, options)
          new_properties << property
          @properties << property
        end
              
        return (new_properties.length == 1 ? new_properties[0] : new_properties)
      end
      
      # Returns an array of Properties for this model.
      def properties
        @properties
      end

    end

  end
end


