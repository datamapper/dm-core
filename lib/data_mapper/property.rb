unless defined?(DM)
  DM = DataMapper::Types
end

require 'date'
require 'time'
require 'bigdecimal'

module DataMapper

  # :include:QUICKLINKS
  #
  # = Properties
  # Properties for a model are not derived from a database structure, but
  # instead explicitly declared inside your model class definitions. These
  # properties then map (or, if using automigrate, generate) fields in your #
  # repository/database.
  #
  # If you are coming to DataMapper from another ORM framework, such as
  # ActiveRecord, this is a fundamental difference in thinking. However, there
  # are several advantages to defining your properties in your models:
  #
  # * information about your model is centralized in one place: rather than
  #   having to dig out migrations, xml or other configuration files.
  # * having information centralized in your models, encourages you and the
  #   developers on your team to take a model-centric view of development.
  # * it provides the ability to use Ruby's access control functions.
  # * and, because DataMapper only cares about properties explicitly defined in
  #   your models, DataMapper plays well with legacy databases, and shares
  #   databases easily with other applications.
  #
  # == Declaring Properties
  # Inside your class, you call the property method for each property you want
  # to add. The only two required arguments are the name and type, everything #
  # else is optional.
  #
  #   class Post
  #     include DataMapper::Resource
  #     property :title,   String,    :nullable => false
  #        # Cannot be null
  #     property :publish, TrueClass, :default => false
  #        # Default value for new records is false
  #   end
  #
  # By default, DataMapper supports the following primitive types:
  #
  # * TrueClass, Boolean
  # * String
  # * Text (limit of 65k characters by default)
  # * Float
  # * Fixnum, Integer
  # * BigDecimal
  # * DateTime
  # * Date
  # * Object (marshalled out during serialization)
  # * Class (datastore primitive is the same as String. Used for Inheritance)
  #
  # For more information about available Types, see DataMapper::Type
  #
  # == Limiting Access
  # Property access control is uses the same terminology Ruby does. Properties
  # are public by default, but can also be declared private or protected as
  # needed (via the :accessor option).
  #
  #  class Post
  #   include DataMapper::Resource
  #    property :title,  String,                  :accessor => :private
  #      # Both reader and writer are private
  #    property :body,   Text, :accessor => :protected
  #      # Both reader and writer are protected
  #  end
  #
  # Access control is also analogous to Ruby accessors and mutators, and can
  # be declared using :reader and :writer, in addition to :accessor.
  #
  #  class Post
  #    include DataMapper::Resource
  #
  #    property :title, String, :writer => :private
  #      # Only writer is private
  #
  #    property :tags,  String, :reader => :protected
  #      # Only reader is protected
  #  end
  #
  # == Overriding Accessors
  # The accessor for any property can be overridden in the same manner that Ruby
  # class accessors can be.  After the property is defined, just add your custom
  # accessor:
  #
  #  class Post
  #    include DataMapper::Resource
  #    property :title,  String
  #
  #    def title=(new_title)
  #      raise ArgumentError if new_title != 'Luke is Awesome'
  #      @title = new_title
  #    end
  #  end
  #
  # == Lazy Loading
  # By default, some properties are not loaded when an object is fetched in
  # DataMapper. These lazily loaded properties are fetched on demand when their
  # accessor is called for the first time (as it is often unnecessary to
  # instantiate -every- property -every- time an object is loaded).  For
  # instance, DataMapper::Types::Text fields are lazy loading by default,
  # although you can over-ride this behavior if you wish:
  #
  # Example:
  #
  #  class Post
  #    include DataMapper::Resource
  #    property :title,  String                    # Loads normally
  #    property :body,   DataMapper::Types::Text   # Is lazily loaded by default
  #  end
  #
  # If you want to over-ride the lazy loading on any field you can set it to a
  # context or false to disable it with the :lazy option. Contexts allow
  # multipule lazy properties to be loaded at one time. If you set :lazy to
  # true, it is placed in the :default context
  #
  #  class Post
  #    include DataMapper::Resource
  #
  #    property :title,    String
  #      # Loads normally
  #
  #    property :body,     DataMapper::Types::Text, :lazy => false
  #      # The default is now over-ridden
  #
  #    property :comment,  String, lazy => [:detailed]
  #      # Loads in the :detailed context
  #
  #    property :author,   String, lazy => [:summary,:detailed]
  #      # Loads in :summary & :detailed context
  #  end
  #
  # Delaying the request for lazy-loaded attributes even applies to objects
  # accessed through associations. In a sense, DataMapper anticipates that
  # you will likely be iterating over objects in associations and rolls all
  # of the load commands for lazy-loaded properties into one request from
  # the database.
  #
  # Example:
  #
  #   Widget[1].components
  #     # loads when the post object is pulled from database, by default
  #
  #   Widget[1].components.first.body
  #     # loads the values for the body property on all objects in the
  #     # association, rather than just this one.
  #
  #   Widget[1].components.first.comment
  #     # loads both comment and author for all objects in the association
  #     # since they are both in the :detailed context
  #
  # == Keys
  # Properties can be declared as primary or natural keys on a table.
  # You should a property as the primary key of the table:
  #
  # Examples:
  #
  #  property :id,        Fixnum, :serial => true  # auto-incrementing key
  #  property :legacy_pk, String, :key => true     # 'natural' key
  #
  # This is roughly equivalent to ActiveRecord's <tt>set_primary_key</tt>,
  # though non-integer data types may be used, thus DataMapper supports natural
  # keys. When a property is declared as a natural key, accessing the object
  # using the indexer syntax <tt>Class[key]</tt> remains valid.
  #
  #   User[1]
  #      # when :id is the primary key on the users table
  #   User['bill']
  #      # when :name is the primary (natural) key on the users table
  #
  # == Inferred Validations
  # If you include the DataMapper::Validate mixin in your model class, you'll
  # benefit from auto-validations: validation rules that are inferred when
  # properties are declared with specific column restrictions.
  #
  #  class Post
  #    include DataMapper::Resource
  #    include DataMapper::Validate
  #
  #    property :title, String, :length => 250
  #      # => infers 'validates_length_of :title,
  #             :minimum => 0, :maximum => 250'
  #
  #    property :title, String, :nullable => false
  #      # => infers 'validates_presence_of :title
  #
  #    property :email, String, :format => :email_address
  #      # => infers 'validates_format_of :email, :with => :email_address
  #
  #    property :title, String, :length => 255, :nullable => false
  #      # => infers both 'validates_length_of' as well as
  #      #    'validates_presence_of'
  #      #    better: property :title, String, :length => 1..255
  #
  #  end
  #
  # The DataMapper::Validate mixin is available with the dm-validations gem,
  # part of the dm-more bundle. For more information about validations, check
  # the documentation for dm-validations.
  #
  # == Embedded Values
  # As an alternative to extraneous has_one relationships, consider using an
  # EmbeddedValue.
  #
  # == Misc. Notes
  # * Properties declared as strings will default to a length of 50, rather than
  #   255 (typical max varchar column size).  To overload the default, pass
  #   <tt>:length => 255</tt> or <tt>:length => 0..255</tt>.  Since DataMapper
  #   does not introspect for properties, this means that legacy database tables
  #   may need their <tt>String</tt> columns defined with a <tt>:length</tt> so
  #   that DM does not apply an un-needed length validation, or allow overflow.
  # * You may declare a Property with the data-type of <tt>Class</tt>.
  #   see SingleTableInheritance for more on how to use <tt>Class</tt> columns.
  class Property

    # NOTE: check is only for psql, so maybe the postgres adapter should
    # define its own property options. currently it will produce a warning tho
    # since PROPERTY_OPTIONS is a constant
    #
    # NOTE: PLEASE update PROPERTY_OPTIONS in DataMapper::Type when updating
    # them here
    PROPERTY_OPTIONS = [
      :public, :protected, :private, :accessor, :reader, :writer,
      :lazy, :default, :nullable, :key, :serial, :field, :size, :length,
      :format, :index, :check, :ordinal, :auto_validation, :validates, :unique,
      :lock, :track, :scale, :precision
    ]

    # FIXME: can we pull the keys from
    # DataMapper::Adapters::DataObjectsAdapter::TYPES
    # for this?
    TYPES = [
      TrueClass,
      String,
      DataMapper::Types::Text,
      Float,
      Fixnum,
      BigDecimal,
      DateTime,
      Date,
      Object,
      Class
    ]

    VISIBILITY_OPTIONS = [ :public, :protected, :private ]

    DEFAULT_LENGTH    = 50
    DEFAULT_PRECISION = 10
    DEFAULT_SCALE     = 0

    attr_reader :primitive, :model, :name, :instance_variable_name,
      :type, :reader_visibility, :writer_visibility, :getter, :options,
      :default, :precision, :scale

    # Supplies the field in the data-store which the property corresponds to
    #
    # ==== Returns
    # String:: name of field in data-store
    #
    # -
    # @semi-public
    def field
      @field ||= @options.fetch(:field, repository.adapter.field_naming_convention.call(name))
    end

    def repository
      @model.repository
    end

    def hash
      return @model.hash + @name.hash
    end

    def eql?(o)
      if o.is_a?(Property)
        return o.model == @model && o.name == @name
      else
        return false
      end
    end
    
    def length
      @length.is_a?(Range) ? @length.max : @length
    end
    alias size length
    
    # Returns whether or not the property is to be lazy-loaded
    #
    # ==== Returns
    # <TrueClass, FalseClass>
    #
    # -
    # @public
    def lazy?
      @lazy
    end


    # Returns whether or not the property is a key or a part of a key
    #
    # ==== Returns
    # <TrueClass, FalseClass>
    #
    #-
    # @public
    def key?
      @key
    end

    # Returns whether or not the property is "serial" (auto-incrementing)
    #
    # ==== Returns
    # <TrueClass, FalseClass>
    #
    #-
    # @public
    def serial?
      @serial
    end

    # Returns whether or not the propert can accept 'nil' as it's value
    # ==== Returns
    # <TrueClass, FalseClass>
    #
    #-
    # @public
    def nullable?
      @nullable
    end

    def lock?
      @lock
    end

    def custom?
      @custom
    end

    # Provides a standardized getter method for the property
    # ==== Raises
    # ArgumentError::
    #   "+resource+ should be a DataMapper::Resource, but was ...."
    #
    #-
    # @private
    def get(resource)
      raise ArgumentError, "+resource+ should be a DataMapper::Resource, but was #{resource.class}" unless Resource === resource
      resource.attribute_get(@name)
    end

    # Provides a standardized setter method for the property
    # ==== Raises
    # ArgumentError::
    #   "+resource+ should be a DataMapper::Resource, but was ...."
    #
    #-
    # @private
    def set(resource, value)
      raise ArgumentError, "+resource+ should be a DataMapper::Resource, but was #{resource.class}" unless Resource === resource
      resource.attribute_set(@name, value)
    end

    # typecasts values into a primitive
    # ==== Returns
    #  <TrueClass, String, Float, Fixnum, BigDecimal, DateTime, Date, Class>::
    # the primitive data-type, defaults to TrueClass
    #
    #-
    # @private
    def typecast(value)
      return value if type === value || value.nil?

      if    type == TrueClass  then true == value || 'true' == value || 1 == value || '1' == value
      elsif type == String     then value.to_s
      elsif type == Float      then value.to_f
      elsif type == Fixnum     then value.to_i
      elsif type == BigDecimal then BigDecimal.new(value.to_s)
      elsif type == DateTime   then DateTime.parse(value.to_s)
      elsif type == Date       then Date.parse(value.to_s)
      elsif type == Class      then find_const(value)
      end
    end

    def default_for(resource)
      @default.respond_to?(:call) ? @default.call(resource, self) : @default
    end

    def inspect
      "#<Property:#{@model}:#{@name}>"
    end

    private

    def initialize(model, name, type, options = {})
      raise ArgumentError, "+model+ is a #{model.class}, but is not a type of Resource"                 unless Resource > model
      raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}"                           unless Symbol === name
      raise ArgumentError, "+type+ was #{type.inspect}, which is not a supported type: #{TYPES * ', '}" unless TYPES.include?(type) || (DataMapper::Type > type && TYPES.include?(type.primitive))

      if (unknown_options = options.keys - PROPERTY_OPTIONS).any?
        raise ArgumentError, "+options+ contained unknown keys: #{unknown_options * ', '}"
      end

      @model                  = model
      @name                   = name.to_s.sub(/\?$/, '').to_sym
      @type                   = type
      @custom                 = DataMapper::Type > @type
      @options                = @custom ? @type.options.merge(options) : options
      @instance_variable_name = "@#{@name}"
      @getter                 = TrueClass == @type ? "#{@name}?".to_sym : @name

      # TODO: This default should move to a DataMapper::Types::Text
      # Custom-Type and out of Property.
      @lazy      = @options.fetch(:lazy,      @type.respond_to?(:lazy)      ? @type.lazy      : false)
      @primitive = @options.fetch(:primitive, @type.respond_to?(:primitive) ? @type.primitive : @type)

      @lock     = @options.fetch(:lock,     false)
      @serial   = @options.fetch(:serial,   false)
      @key      = @options.fetch(:key,      @serial || false)
      @default  = @options.fetch(:default,  nil)
      @nullable = @options.fetch(:nullable, @key == false && @default.nil?)

      # assign attributes per-type
      if @primitive == String || @primitive == Class
        @length = @options.fetch(:length, @options.fetch(:size, DEFAULT_LENGTH))
      elsif @primitive == BigDecimal
        @precision = @options.fetch(:precision, DEFAULT_PRECISION)
        @scale     = @options.fetch(:scale,     DEFAULT_SCALE)
      end

      determine_visibility

      create_getter
      create_setter

      @model.auto_generate_validations(self) if @model.respond_to?(:auto_generate_validations)
      @model.property_serialization_setup(self) if @model.respond_to?(:property_serialization_setup)
      
      @type.bind(self) if @custom
    end

    def determine_visibility # :nodoc:
      @reader_visibility = @options[:reader] || @options[:accessor] || :public
      @writer_visibility = @options[:writer] || @options[:accessor] || :public
      @writer_visibility = :protected if @options[:protected]
      @writer_visibility = :private   if @options[:private]
      raise ArgumentError, "property visibility must be :public, :protected, or :private" unless VISIBILITY_OPTIONS.include?(@reader_visibility) && VISIBILITY_OPTIONS.include?(@writer_visibility)
    end

    # defines the getter for the property
    def create_getter
      if @primitive == TrueClass && !@model.instance_methods.include?(@name.to_s)
        @model.class_eval <<-EOS, __FILE__, __LINE__
          #{reader_visibility}
          def #{@name}
            self.attribute_get(#{name.inspect})
          end
        EOS
      end

      @model.class_eval <<-EOS, __FILE__, __LINE__
        #{reader_visibility}
        def #{@getter}
          self.attribute_get(#{name.inspect})
        end
      EOS
    end

    # defines the setter for the property
    def create_setter
      @model.class_eval <<-EOS, __FILE__, __LINE__
        #{writer_visibility}
        def #{name}=(value)
          self.attribute_set(#{name.inspect}, value)
        end
      EOS
    end
  end # class Property
end # module DataMapper
