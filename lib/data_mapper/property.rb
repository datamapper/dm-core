require __DIR__ + 'property_set'
require __DIR__ + 'type'

require 'date'
require 'time'
require 'bigdecimal'

class Text; end; warn('Text should not be declared inline.')

module DataMapper

# :include:/QUICKLINKS
#
# = Properties
# A model's properties are not derived from database structure.
# Instead, properties are declared inside it's model's class definition,
# which map to (or generate) fields in a database.
# 
# Defining properties explicitly in a model has several advantages.
# It centralizes information about the model
# in a single location, rather than having to dig out migrations, xml,
# or other config files.  It also provides the ability to use Ruby's
# access control functions.  Finally, since Datamapper only cares about
# properties explicitly defined in your models, Datamappers plays well
# with legacy databases and shares databases easily with other
# applications.
#
# == Declaring Properties
# Inside your class, you call the property method for each property you want to add. 
# The only two required arguments are the name and type, everything else is optional.
# 
#   class Post < DataMapper::Base
#     property :title,   :string, :nullable => false # Cannot be null
#     property :publish, :boolen, :default  => false # Default value for new records 
#                                                      is false
#   end
# 
# == Declaring Multiple Properties
# You can declare multiple properties with the same type and options with one call to
# the property method. There is no limit to the amount of properties that can be created,
# and the only required arguments are the property names and type. Everything else is optional.
# 
#   class Cellphone < DataMapper::Base
#     # You can pass the property names in a simple list, like below.
#     property :name, :model, :make, :text, :nullable => false
# 
#     # Alternatively, you can pass an array of property names as the first argument.
#     property [:black, :white], :boolean, :default => true
#     property [:red, :blue, :green, :orange, :pink], :boolean, :default => false
#   end  
# 
# == Limiting Access
# Property access control is uses the same terminology Ruby does. Properties are 
# public by default, but can also be declared private or protected as needed 
# (via the :accessor option).
# 
#  class Post < DataMapper::Base
#    property :title,  :string, :accessor => :private   # Both reader and writer are private
#    property :body,   :text,   :accessor => :protected # Both reader and writer are protected
#  end
# 
# Access control is also analogous to Ruby getters, setters, and accessors, and can 
# be declared using :reader and :writer, in addition to :accessor.
# 
#  class Post < DataMapper::Base
#    property :title, :string, :writer => :private    # Only writer is private
#    property :tags,  :string, :reader => :protected  # Only reader is protected
#  end
#
# == Overriding Accessors
# The accessor for any property can be overridden in the same manner that Ruby class accessors 
# can be.  After the property is defined, just add your custom accessor:
# 
#  class Post < DataMapper::Base
#    property :title,  :string
#    
#    def title=(new_title)
#      raise ArgumentError if new_title != 'Luke is Awesome'
#      @title = new_title
#    end
#  end
#
# == Lazy Loading
# By default, some properties are not loaded when an object is fetched in Datamapper.  
# These lazily loaded properties are fetched on demand when their accessor is called 
# for the first time (as it is often unnecessary to instantiate -every- property 
# -every- time an object is loaded).  For instance, text fields are lazy loading by 
# default, although you can over-ride this behavior if you wish:
#
# Example:
# 
#  class Post < DataMapper::Base
#    property :title,  :string   # Loads normally
#    property :body,   :text     # Is lazily loaded by default
#  end
# 
# If you want to over-ride the lazy loading on any field you can set it to true or 
# false with the :lazy option.
# 
#  class Post < DataMapper::Base
#    property :title,  :string               # Loads normally
#    property :body,   :text, :lazy => false # The default is now over-ridden
#  end
#
# Delaying the request for lazy-loaded attributes even applies to objects accessed through 
# associations. In a sense, Datamapper anticipates that you will likely be iterating 
# over objects in associations and rolls all of the load commands for lazy-loaded 
# properties into one request from the database.
#
# Example:
#
#   Widget[1].components                    # loads when the post object is pulled from database, by default
#   Widget[1].components.first.body         # loads the values for the body property on all objects in the
#                                             association, rather than just this one.
#                                                    
# == Keys
# Properties can be declared as primary or natural keys on a table.  By default, 
# Datamapper will assume <tt>:id</tt> and create it if you don't have it.  
# You can, however, declare a property as the primary key of the table:
#
#  property :legacy_pk, :string, :key => true
#
# This is roughly equivalent to Activerecord's <tt>set_primary_key</tt>, though 
# non-integer data types may be used, thus Datamapper supports natural keys. 
# When a property is declared as a natural key, accessing the object using the 
# indexer syntax <tt>Class[key]</tt> remains valid.
#
#   User[1] when :id is the primary key on the users table
#   User['bill'] when :name is the primary (natural) key on the users table
#
# == Inferred Validations
# When properties are declared with specific column restrictions, Datamapper 
# will infer a few validation rules for values assigned to that property.
#
#  property :title, :string, :length => 250
#  # => infers 'validates_length_of :title, :minimum => 0, :maximum => 250'
#
#  property :title, :string, :nullable => false
#  # => infers 'validates_presence_of :title
#
#  property :email, :string, :format => :email_address
#  # => infers 'validates_format_of :email, :with => :email_address
#
#  property :title, :string, :length => 255, :nullable => false
#  # => infers both 'validates_length_of' as well as 'validates_presence_of'
#  #    better: property :title, :string, :length => 1..255
#
# For more information about validations, visit the Validatable documentation.
# == Embedded Values
# As an alternative to extraneous has_one relationships, consider using an
# EmbeddedValue.
#
# == Misc. Notes
# * Properties declared as strings will default to a length of 50, rather than 255 
#   (typical max varchar column size).  To overload the default, pass 
#   <tt>:length => 255</tt> or <tt>:length => 0..255</tt>.  Since Datamapper does 
#   not introspect for properties, this means that legacy database tables may need 
#   their <tt>:string</tt> columns defined with a <tt>:length</tt> so that DM does 
#   not inadvertantly truncate data.
# * You may declare a Property with the data-type of <tt>:class</tt>.  
#   see SingleTableInheritance for more on how to use <tt>:class</tt> columns.
  class Property
    
    # NOTE: check is only for psql, so maybe the postgres adapter should define
    # its own property options. currently it will produce a warning tho since
    # PROPERTY_OPTIONS is a constant
    # NOTE2: PLEASE update PROPERTY_OPTIONS in DataMapper::Type when updating them here
    PROPERTY_OPTIONS = [
      :public, :protected, :private, :accessor, :reader, :writer,
      :lazy, :default, :nullable, :key, :serial, :field, :size, :length,
      :format, :index, :check, :ordinal, :auto_validation, :validation_context
    ]
    
    TYPES = [
      TrueClass,
      String,
      Text,
      Float,
      Fixnum,
      BigDecimal,
      DateTime,
      Date,
      Object,
      Class
    ]
    
    VISIBILITY_OPTIONS = [:public, :protected, :private]
    
    def initialize(target, name, type, options)
      
      raise ArgumentError.new("#{target.inspect} should be a type of Resource") unless Resource === target
      raise ArgumentError.new("#{name.inspect} should be a Symbol") unless name.is_a?(Symbol)
      raise ArgumentError.new("#{type.inspect} is not a supported type. Valid types are:\n #{TYPES.inspect}") unless TYPES.include?(type) || (type.ancestors.include?(DataMapper::Type) && TYPES.include?(type.primitive))
      
      @target, @name, @type = target, name.to_s.sub(/\?$/, '').to_sym, type
      @options = type.ancestors.include?(DataMapper::Type) ? type.options.merge(options) : options
      
      @instance_variable_name = "@#{@name}"
      
      @field = @options.fetch(:field, name.to_s.sub(/\?$/, ''))
      
      @getter = @type.is_a?(TrueClass) ? @name.to_s.ensure_ends_with('?').to_sym : @name
      
      @lazy = @options.has_key?(:lazy) ? @options[:lazy] : @type == Text
      
      @key = (@options[:key] || @options[:serial]) == true
      @serial = @options.fetch(:serial, false)
      
      validate_options!
      determine_visibility!
      
      create_getter!
      create_setter!
      
      # Auto validation has moved to dm-more 
      # auto_generate_validations_for_property is mixed in from
      # DataMapper::Validate::AutoValidate in dm-more
      target.auto_generate_validations_for_property(self) if target.respond_to?(:auto_generate_validations_for_property)        
    end
    
    def validate_options! # :nodoc:
      @options.each_pair do |k,v|
        raise ArgumentError.new("#{k.inspect} is not a supported option in DataMapper::Property::PROPERTY_OPTIONS") unless PROPERTY_OPTIONS.include?(k)
      end
    end
    
    def determine_visibility! # :nodoc:
      @reader_visibility = @options[:reader] || @options[:accessor] || :public
      @writer_visibility = @options[:writer] || @options[:accessor] || :public
      @writer_visibility = :protected if @options[:protected]
      @writer_visibility = :private if @options[:private]
      raise(ArgumentError.new, "property visibility must be :public, :protected, or :private") unless VISIBILITY_OPTIONS.include?(@reader_visibility) && VISIBILITY_OPTIONS.include?(@writer_visibility)
    end
    
    # defines the getter for the property
    def create_getter!
      @target.class_eval <<-EOS
      #{reader_visibility.to_s}
      def #{name}
        attribute_get(#{name.inspect})
      end
      EOS
      
      if type == TrueClass
        @target.class_eval <<-EOS
        #{reader_visibility.to_s}
        def #{name.to_s.ensure_ends_with('?')}
          attribute_get(#{name.inspect})
        end
        EOS
      end
    rescue SyntaxError
      raise SyntaxError.new(column)
    end
    
    # defines the setter for the property
    def create_setter!
      @target.class_eval <<-EOS
      #{writer_visibility.to_s}
      def #{name}=(value)
        attribute_set(#{name.inspect}, value)
      end
      EOS
    rescue SyntaxError
      raise SyntaxError.new(column)
    end
  
    def primitive
      @type.ancestors.include?(DataMapper::Type) ? @type.primitive : @type
    end
    
    def target
      @target
    end
    
    def field
      @field
    end
     
    def name
      @name
    end
    
    def instance_variable_name # :nodoc:
      @instance_variable_name
    end
    
    def type
      @type
    end
    
    def reader_visibility # :nodoc:
      @reader_visibility
    end
    
    def writer_visibility # :nodoc:
      @writer_visibility
    end
    
    def lazy?
      @lazy
    end
    
    def getter
      @getter
    end
    
    def key?
      @key
    end
    
    def serial?
      @serial
    end
    
    def options
      @options
    end
    
    def inspect
      "#<Property #{@target}:#{@name}>"
    end 
  end
end
