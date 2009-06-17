module DataMapper

  # :include:QUICKLINKS
  #
  # = Properties
  # Properties for a model are not derived from a database structure, but
  # instead explicitly declared inside your model class definitions. These
  # properties then map (or, if using automigrate, generate) fields in your
  # repository/database.
  #
  # If you are coming to DataMapper from another ORM framework, such as
  # ActiveRecord, this may be a fundamental difference in thinking to you.
  # However, there are several advantages to defining your properties in your
  # models:
  #
  # * information about your model is centralized in one place: rather than
  #   having to dig out migrations, xml or other configuration files.
  # * use of mixins can be applied to model properties: better code reuse
  # * having information centralized in your models, encourages you and the
  #   developers on your team to take a model-centric view of development.
  # * it provides the ability to use Ruby's access control functions.
  # * and, because DataMapper only cares about properties explicitly defined
  # in
  #   your models, DataMapper plays well with legacy databases, and shares
  #   databases easily with other applications.
  #
  # == Declaring Properties
  # Inside your class, you call the property method for each property you want
  # to add. The only two required arguments are the name and type, everything
  # else is optional.
  #
  #   class Post
  #     include DataMapper::Resource
  #
  #     property :title,   String,  :nullable => false  # Cannot be null
  #     property :publish, Boolean, :default => false   # Default value for new records is false
  #   end
  #
  # By default, DataMapper supports the following primitive (Ruby) types
  # also called core types:
  #
  # * TrueClass, Boolean
  # * String (default length is 50)
  # * Text (limit of 65k characters by default)
  # * Float
  # * Integer
  # * BigDecimal
  # * DateTime
  # * Date
  # * Time
  # * Object (marshalled out during serialization)
  # * Class (datastore primitive is the same as String. Used for Inheritance)
  #
  # Other types are known as custom types.
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
  #
  #    property :title, String, :accessor => :private    # Both reader and writer are private
  #    property :body,  Text,   :accessor => :protected  # Both reader and writer are protected
  #  end
  #
  # Access control is also analogous to Ruby attribute readers and writers, and can
  # be declared using :reader and :writer, in addition to :accessor.
  #
  #  class Post
  #    include DataMapper::Resource
  #
  #    property :title, String, :writer => :private    # Only writer is private
  #    property :tags,  String, :reader => :protected  # Only reader is protected
  #  end
  #
  # == Overriding Accessors
  # The reader/writer for any property can be overridden in the same manner that Ruby
  # attr readers/writers can be.  After the property is defined, just add your custom
  # reader or writer:
  #
  #  class Post
  #    include DataMapper::Resource
  #
  #    property :title, String
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
  #
  #    property :title, String  # Loads normally
  #    property :body,  Text    # Is lazily loaded by default
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
  #    property :title,   String                                    # Loads normally
  #    property :body,    Text,   :lazy => false                    # The default is now over-ridden
  #    property :comment, String, :lazy => [ :detailed ]            # Loads in the :detailed context
  #    property :author,  String, :lazy => [ :summary, :detailed ]  # Loads in :summary & :detailed context
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
  #   Widget.get(1).components
  #     # loads when the post object is pulled from database, by default
  #
  #   Widget.get(1).components.first.body
  #     # loads the values for the body property on all objects in the
  #     # association, rather than just this one.
  #
  #   Widget.get(1).components.first.comment
  #     # loads both comment and author for all objects in the association
  #     # since they are both in the :detailed context
  #
  # == Keys
  # Properties can be declared as primary or natural keys on a table.
  # You should a property as the primary key of the table:
  #
  # Examples:
  #
  #  property :id,        Serial                # auto-incrementing key
  #  property :legacy_pk, String, :key => true  # 'natural' key
  #
  # This is roughly equivalent to ActiveRecord's <tt>set_primary_key</tt>,
  # though non-integer data types may be used, thus DataMapper supports natural
  # keys. When a property is declared as a natural key, accessing the object
  # using the indexer syntax <tt>Class[key]</tt> remains valid.
  #
  #   User.get(1)
  #      # when :id is the primary key on the users table
  #   User.get('bill')
  #      # when :name is the primary (natural) key on the users table
  #
  # == Indices
  # You can add indices for your properties by using the <tt>:index</tt>
  # option. If you use <tt>true</tt> as the option value, the index will be
  # automatically named. If you want to name the index yourself, use a symbol
  # as the value.
  #
  #   property :last_name,  String, :index => true
  #   property :first_name, String, :index => :name
  #
  # You can create multi-column composite indices by using the same symbol in
  # all the columns belonging to the index. The columns will appear in the
  # index in the order they are declared.
  #
  #   property :last_name,  String, :index => :name
  #   property :first_name, String, :index => :name
  #      # => index on (last_name, first_name)
  #
  # If you want to make the indices unique, use <tt>:unique_index</tt> instead
  # of <tt>:index</tt>
  #
  # == Inferred Validations
  # If you require the dm-validations plugin, auto-validations will
  # automatically be mixed-in in to your model classes:
  # validation rules that are inferred when properties are declared with
  # specific column restrictions.
  #
  #  class Post
  #    include DataMapper::Resource
  #
  #    property :title, String, :length => 250
  #      # => infers 'validates_length :title,
  #             :minimum => 0, :maximum => 250'
  #
  #    property :title, String, :nullable => false
  #      # => infers 'validates_present :title
  #
  #    property :email, String, :format => :email_address
  #      # => infers 'validates_format :email, :with => :email_address
  #
  #    property :title, String, :length => 255, :nullable => false
  #      # => infers both 'validates_length' as well as
  #      #    'validates_present'
  #      #    better: property :title, String, :length => 1..255
  #
  #  end
  #
  # This functionality is available with the dm-validations gem, part of the
  # dm-more bundle. For more information about validations, check the
  # documentation for dm-validations.
  #
  # == Default Values
  # To set a default for a property, use the <tt>:default</tt> key.  The
  # property will be set to the value associated with that key the first time
  # it is accessed, or when the resource is saved if it hasn't been set with
  # another value already.  This value can be a static value, such as 'hello'
  # but it can also be a proc that will be evaluated when the property is read
  # before its value has been set.  The property is set to the return of the
  # proc.  The proc is passed two values, the resource the property is being set
  # for and the property itself.
  #
  #   property :display_name, String, :default => { |resource, property| resource.login }
  #
  # Word of warning.  Don't try to read the value of the property you're setting
  # the default for in the proc.  An infinite loop will ensue.
  #
  # == Embedded Values
  # As an alternative to extraneous has_one relationships, consider using an
  # EmbeddedValue.
  #
  # == Property options reference
  #
  #  :accessor            if false, neither reader nor writer methods are
  #                       created for this property
  #
  #  :reader              if false, reader method is not created for this property
  #
  #  :writer              if false, writer method is not created for this property
  #
  #  :lazy                if true, property value is only loaded when on first read
  #                       if false, property value is always loaded
  #                       if a symbol, property value is loaded with other properties
  #                       in the same group
  #
  #  :default             default value of this property
  #
  #  :nullable            if true, property may have a nil value on save
  #
  #  :key                 name of the key associated with this property.
  #
  #  :serial              if true, field value is auto incrementing
  #
  #  :field               field in the data-store which the property corresponds to
  #
  #  :size                field size. Usually makes sense for properties of type String.
  #
  #  :length              alias for :length option
  #
  #  :format              format for autovalidation. Use with dm-validations plugin.
  #
  #  :index               if true, index is created for the property. If a Symbol, index
  #                       is named after Symbol value instead of being based on property name.
  #
  #  :unique_index        true specifies that index on this property should be unique
  #
  #  :auto_validation     if true, automatic validation is performed on the property
  #
  #  :validates           validation context. Use together with dm-validations.
  #
  #  :unique              if true, property column is unique. Properties of type Serial
  #                       are unique by default.
  #
  #  :precision           Indicates the number of significant digits. Usually only makes sense
  #                       for float type properties. Must be >= scale option value. Default is 10.
  #
  #  :scale               The number of significant digits to the right of the decimal point.
  #                       Only makes sense for float type properties. Must be > 0.
  #                       Default is nil for Float type and 10 for BigDecimal type.
  #
  #  All other keys you pass to +property+ method are stored and available
  #  as options[:extra_keys].
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
    include Extlib::Assertions
    extend Deprecate

    deprecate :unique, :unique?

    # NOTE: check is only for psql, so maybe the postgres adapter should
    # define its own property options. currently it will produce a warning tho
    # since OPTIONS is a constant
    #
    # NOTE: PLEASE update OPTIONS in DataMapper::Type when updating
    # them here
    OPTIONS = [
      :accessor, :reader, :writer,
      :lazy, :default, :nullable, :key, :serial, :field, :size, :length,
      :format, :index, :unique_index, :auto_validation,
      :validates, :unique, :precision, :scale
    ]

    PRIMITIVES = [
      TrueClass,
      String,
      Float,
      Integer,
      BigDecimal,
      DateTime,
      Date,
      Time,
      Object,
      Class,
    ].to_set.freeze

    # Possible :visibility option values
    VISIBILITY_OPTIONS = [ :public, :protected, :private ].to_set.freeze

    DEFAULT_LENGTH           = 50
    DEFAULT_PRECISION        = 10
    DEFAULT_SCALE_BIGDECIMAL = 0    # Default scale for BigDecimal type
    DEFAULT_SCALE_FLOAT      = nil  # Default scale for Float type

    attr_reader :primitive, :model, :name, :instance_variable_name,
      :type, :reader_visibility, :writer_visibility, :options,
      :default, :precision, :scale, :repository_name

    # Supplies the field in the data-store which the property corresponds to
    #
    # @return [String] name of field in data-store
    #
    # @api semipublic
    def field(repository_name = nil)
      if repository_name
        warn "Passing in +repository_name+ to #{self.class}#field is deprecated (#{caller[0]})"

        if repository_name != self.repository_name
          raise ArgumentError, "Mismatching +repository_name+ with #{self.class}#repository_name (#{repository_name.inspect} != #{self.repository_name.inspect})"
        end
      end

      # defer setting the field with the adapter specific naming
      # conventions until after the adapter has been setup
      @field ||= model.field_naming_convention(self.repository_name).call(self).freeze
    end

    # Returns true if property is unique. Serial properties and keys
    # are unique by default.
    #
    # @return [TrueClass, FalseClass]
    #   true if property has uniq index defined, false otherwise
    #
    # @api public
    def unique?
      @unique
    end

    ##
    # Compares another Property for equivalency
    #
    #   TODO: needs example
    #
    # @param [Property] other
    #   the other Property to compare with
    #
    # @return [TrueClass, FalseClass]
    #   true if they are equivalent, false if not
    #
    # @api semipublic
    def ==(other)
      if equal?(other)
        return true
      end

      unless other.respond_to?(:model) && other.respond_to?(:name)
        return false
      end

      cmp?(other, :==)
    end

    ##
    # Compares another Property for equality
    #
    #   TODO: needs example
    #
    # @param [Property] other
    #   the other Property to compare with
    #
    # @return [TrueClass, FalseClass]
    #   true if they are equal, false if not
    #
    # @api semipublic
    def eql?(other)
      if equal?(other)
        return true
      end

      unless other.kind_of?(self.class)
        return false
      end

      cmp?(other, :eql?)
    end

    ##
    # Returns the hash of the property name
    #
    # This is necessary to allow comparisons between different properties
    # in different models, having the same base model
    #
    # @return [Integer]
    #   the property name hash
    #
    # @api semipublic
    def hash
      name.hash
    end

    # Returns maximum property length (if applicable).
    # This usually only makes sense when property is of
    # type Range or custom type.
    #
    # @return [Integer, NilClass]
    #   the maximum length of this property
    #
    # @api semipublic
    def length
      @length.kind_of?(Range) ? @length.max : @length
    end

    alias size length

    # Returns index name if property has index.
    #
    # @return [TrueClass, Symbol, Array, NilClass]
    #   returns true if property is indexed by itself
    #   returns a Symbol if the property is indexed with other properties
    #   returns an Array if the property belongs to multiple indexes
    #   returns nil if the property does not belong to any indexes
    #
    # @api public
    def index
      @index
    end

    # Returns true if property has unique index. Serial properties and
    # keys are unique by default.
    #
    # @return [TrueClass, Symbol, Array, NilClass]
    #   returns true if property is indexed by itself
    #   returns a Symbol if the property is indexed with other properties
    #   returns an Array if the property belongs to multiple indexes
    #   returns nil if the property does not belong to any indexes
    #
    # @api public
    def unique_index
      @unique_index
    end

    # Returns whether or not the property is to be lazy-loaded
    #
    # @return [TrueClass, FalseClass]
    #   true if the property is to be lazy-loaded
    #
    # @api public
    def lazy?
      @lazy
    end

    # Returns whether or not the property is a key or a part of a key
    #
    # @return [TrueClass, FalseClass]
    #   true if the property is a key or a part of a key
    #
    # @api public
    def key?
      @key
    end

    # Returns whether or not the property is "serial" (auto-incrementing)
    #
    # @return [TrueClass, FalseClass]
    #   whether or not the property is "serial"
    #
    # @api public
    def serial?
      @serial
    end

    # Returns whether or not the property can accept 'nil' as it's value
    #
    # @return [TrueClass, FalseClass]
    #   whether or not the property can accept 'nil'
    #
    # @api public
    def nullable?
      @nullable
    end

    # Returns whether or not the property is custom (not provided by dm-core)
    #
    # @return [TrueClass, FalseClass]
    #   whether or not the property is custom
    #
    # @api public
    def custom?
      @custom
    end

    # Standardized reader method for the property
    #
    # @param [Resource] resource
    #   model instance for which this property is to be loaded
    #
    # @return [Object]
    #   the value of this property for the provided instance
    #
    # @raise [ArgumentError] "+resource+ should be a Resource, but was ...."
    #
    # @api private
    def get(resource)
      lazy_load(resource) unless loaded?(resource) || resource.new?

      if loaded?(resource)
        get!(resource)
      else
        set(resource, default? ? default_for(resource) : nil)
      end
    end

    # Bypases resource loading and returns value of
    # @ivar on the object directly.
    #
    # Keep in mind this method is not safe and should be
    # used with care.
    #
    # @param [Resource] resource
    #   model instance for which this property is to be unsafely loaded
    #
    # @return [Object]
    #   current @ivar value of this property in +resource+
    #
    # @api private
    def get!(resource)
      resource.instance_variable_get(instance_variable_name)
    end

    # Sets original value of the property on given resource.
    # When property is set on DataMapper resource instance,
    # original value is preserved. This makes possible to
    # track dirty attributes and save only those really changed,
    # and avoid extra queries to the data source in certain
    # situations.
    #
    # @param [Resource] resource
    #   model instance for which to set the original value
    # @param [Object] original
    #   value to set as original value for this property in +resource+
    #
    # @api private
    def set_original_value(resource, original)
      original_attributes = resource.original_attributes
      original        = self.value(original)

      if original_attributes.key?(self)
        # stop tracking the value if it has not changed
        original_attributes.delete(self) if original == original_attributes[self] && resource.saved?
      else
        original_attributes[self] = original
      end
    end

    # Provides a standardized setter method for the property
    #
    # @param [Resource] resource
    #   model instance for which this property is to be set
    # @param [Object] value
    #   value to which value of this property will be set for +resource+
    #
    # @return [Object]
    #   +value+ after being typecasted according to this property's primitive
    #
    # @raise [ArgumentError] "+resource+ should be a Resource, but was ...."
    #
    # @api private
    def set(resource, value)
      loaded   = loaded?(resource)
      original = get!(resource) if loaded
      value    = typecast(value)

      if loaded && value == original
        return original
      end

      set_original_value(resource, original)

      set!(resource, value)
    end

    # Bypases resource loading and sets value on
    # @ivar of the object directly.
    #
    # Keep in mind this method is not safe and should be
    # used with care.
    #
    # @param [Resource] resource
    #   the model instance for which to unsafely set the value of this property
    # @param [Object] value
    #   the value to which this property should be unsafely set for +resource+
    #
    # @return [Object]
    #   +value+, the value to which this property was unsafely set for +resource+
    #
    # @api private
    def set!(resource, value)
      resource.instance_variable_set(instance_variable_name, value)
    end

    # Check if the attribute corresponding to the property is loaded
    #
    # @param [Resource] resource
    #   model instance for which the attribute is to be tested
    #
    # @return [TrueClass, FalseClass]
    #   true if the attribute is loaded in the resource
    #
    # @api private
    def loaded?(resource)
      resource.instance_variable_defined?(instance_variable_name)
    end

    # Loads lazy columns when get or set is called.
    #
    # @param [Resource] resource
    #   model instance for which lazy loaded attribute are loaded
    #
    # @api private
    def lazy_load(resource)
      # If we're trying to load a lazy property, load it. Otherwise, lazy-load
      # any properties that should be eager-loaded but were not included
      # in the original :fields list
      property_names = lazy? ? [ name ] : model.properties(resource.repository.name).defaults.map { |property| property.name }
      resource.send(:lazy_load, property_names)
    end

    # typecasts values into a primitive (Ruby class that backs DataMapper
    # property type). If property type can handle typecasting, it is delegated.
    # How typecasting is perfomed, depends on the primitive of the type.
    #
    # If type's primitive is a TrueClass, values of 1, t and true are casted to true.
    #
    # For String primitive, +to_s+ is called on value.
    #
    # For Float primitive, +to_f+ is called on value.
    #
    # For Integer primitive, +to_i+ is called on value but only if value is an integer
    # (decimal or binary), otherwise nil is returned. This is so because "junk".to_i
    # returns 0.
    #
    # Properties of type with BigDecimal primitive use +BigDecimal(value)+ for casting.
    # Casting to DateTime, Time and Date can handle both hashes with keys like :day or
    # :hour and strings in format methods like Time.parse can handle.
    #
    # @param [#to_s, #to_f, #to_i] value
    #   the value to be typecast to this property's primitive
    #
    # @return [TrueClass, String, Float, Integer, BigDecimal, DateTime, Date, Time, Class]
    #   The typecasted +value+
    #
    # @api private
    def typecast(value)
      return type.typecast(value, self) if type.respond_to?(:typecast)
      return value if value.kind_of?(primitive) || value.nil?
      begin
        # TODO: optimize this using a Hash lookup table
        if primitive == Integer
          # only typecast a String that looks like a number
          value.to_s =~ /\A(-?(?:0+|[1-9]\d*)(?:\.\d+)?)\z/ ? $1.to_i : value
        elsif primitive == String     then value.to_s
        elsif primitive == TrueClass  then %w[ true 1 t ].include?(value.to_s.downcase)
        elsif primitive == BigDecimal then BigDecimal(value.to_s)
        elsif primitive == Float      then value.to_f
        elsif primitive == DateTime   then typecast_to_datetime(value)
        elsif primitive == Time       then typecast_to_time(value)
        elsif primitive == Date       then typecast_to_date(value)
        elsif primitive == Class      then self.class.find_const(value)
        else
          value
        end
      rescue
        value
      end
    end

    # Returns a default value of the
    # property for given resource.
    #
    # When default value is a callable object,
    # it is called with resource and property passed
    # as arguments.
    #
    # @param [Resource] resource
    #   the model instance for which the default is to be set
    #
    # @return [Object]
    #   the default value of this property for +resource+
    #
    # @api semipublic
    def default_for(resource)
      @default.respond_to?(:call) ? @default.call(resource, self) : @default.try_dup
    end

    # Returns true if the property has a default value
    #
    # @return [TrueClass, FalseClass]
    #   true if the property has a default value
    #
    # @api semipublic
    def default?
      @options.key?(:default)
    end

    # Returns given value unchanged for core types and
    # uses +dump+ method of the property type for custom types.
    #
    # @param [Object] value
    #   the value to be converted into a storeable (ie., primitive) value
    #
    # @return [Object]
    #   the primitive value to be stored in the repository for +val+
    #
    # @api semipublic
    def value(value)
      custom? ? type.dump(value, self) : value
    end

    ##
    # Test the value to see if it is a valid value for this Property
    #
    # @param [Object] value
    #   the value to be tested
    #
    # @return [TrueClass, FalseClass]
    #   true if the value is valid
    #
    # @api semipulic
    def valid?(value)
      value.kind_of?(primitive) || (value.nil? && nullable?)
    end

    # Returns a concise string representation of the property instance.
    #
    # @return [String]
    #   Concise string representation of the property instance.
    #
    # @api public
    def inspect
      "#<#{self.class.name} @model=#{model.inspect} @name=#{name.inspect}>"
    end

    private

    # TODO: document
    # @api semipublic
    def initialize(model, name, type, options = {})
      assert_kind_of 'model',   model,   Model
      assert_kind_of 'name',    name,    Symbol
      assert_kind_of 'type',    type,    Class, Module
      assert_kind_of 'options', options, Hash

      options = options.dup

      if TrueClass == type
        warn "#{type} is deprecated, use Boolean instead at #{caller[2]}"
        type = Types::Boolean
      elsif Integer == type && options.delete(:serial)
        warn "#{type} with explicit :serial option is deprecated, use Serial instead"
        type = Types::Serial
      elsif String == type && options.key?(:size)
        warn "#{type} with :size option is deprecated, use #{type} with :length instead"
        options[:length] = options.delete(:size)
      end

      assert_valid_options(options)

      # if the type can be found within Types then
      # use that class rather than the primitive
      unless type.name.blank?
        type = Types.find_const(type.name)
      end

      unless PRIMITIVES.include?(type) || (Type > type && PRIMITIVES.include?(type.primitive))
        raise ArgumentError, "+type+ was #{type.inspect}, which is not a supported type"
      end

      @repository_name        = model.repository_name
      @model                  = model
      @name                   = name.to_s.sub(/\?$/, '').to_sym
      @type                   = type
      @custom                 = Type > @type
      @options                = (@custom ? @type.options.merge(options) : options.dup).freeze
      @instance_variable_name = "@#{@name}".freeze

      @primitive = @type.respond_to?(:primitive) ? @type.primitive : @type
      @field     = @options[:field].freeze
      @default   = @options[:default]

      @serial       = @options.fetch(:serial,       false)
      @key          = @options.fetch(:key,          @serial || false)
      @nullable     = @options.fetch(:nullable,     @key == false)
      @index        = @options.fetch(:index,        nil)
      @unique_index = @options.fetch(:unique_index, nil)
      @unique       = @options.fetch(:unique,       @serial || @key || false)
      @lazy         = @options.fetch(:lazy,         @type.respond_to?(:lazy) ? @type.lazy : false) && !@key

      # assign attributes per-type
      if String == @primitive || Class == @primitive
        @length = @options.fetch(:length, DEFAULT_LENGTH)
      elsif BigDecimal == @primitive || Float == @primitive
        @precision = @options.fetch(:precision, DEFAULT_PRECISION)
        @scale     = @options.fetch(:scale,     Float == @primitive ? DEFAULT_SCALE_FLOAT : DEFAULT_SCALE_BIGDECIMAL)

        unless @precision > 0
          raise ArgumentError, "precision must be greater than 0, but was #{@precision.inspect}"
        end

        unless Float == @primitive && @scale.nil?
          unless @scale >= 0
            raise ArgumentError, "scale must be equal to or greater than 0, but was #{@scale.inspect}"
          end

          unless @precision >= @scale
            raise ArgumentError, "precision must be equal to or greater than scale, but was #{@precision.inspect} and scale was #{@scale.inspect}"
          end
        end
      end

      determine_visibility

      if custom?
        type.bind(self)
      end

      # comes from dm-validations
      @model.auto_generate_validations(self) if @model.respond_to?(:auto_generate_validations)
    end

    # TODO: document
    # @api private
    def assert_valid_options(options)
      if (unknown_keys = options.keys - OPTIONS).any?
        raise ArgumentError, "options #{unknown_keys.map { |key| key.inspect }.join(' and ')} are unknown"
      end

      options.each do |key, value|
        case key
          when :field
            assert_kind_of "options[#{key.inspect}]", value, String

          when :default
            if value.nil?
              raise ArgumentError, "options[#{key.inspect}] must not be nil"
            end

          when :serial, :key, :nullable, :unique, :lazy, :auto_validation
            unless value == true || value == false
              raise ArgumentError, "options[#{key.inspect}] must be either true or false"
            end

          when :index, :unique_index
            assert_kind_of "options[#{key.inspect}]", value, Symbol, Array, TrueClass

          when :length
            assert_kind_of "options[#{key.inspect}]", value, Range, Integer

          when :size, :precision, :scale
            assert_kind_of "options[#{key.inspect}]", value, Integer

          when :reader, :writer, :accessor
            assert_kind_of "options[#{key.inspect}]", value, Symbol

            unless VISIBILITY_OPTIONS.include?(value)
              raise ArgumentError, "options[#{key.inspect}] must be #{VISIBILITY_OPTIONS.join(' or ')}"
            end
        end
      end
    end

    # Assert given visibility value is supported.
    #
    # Will raise ArgumentError if this Property's reader and writer
    # visibilities are not included in VISIBILITY_OPTIONS.
    # @return [NilClass]
    #
    # @raise [ArgumentError] "property visibility must be :public, :protected, or :private"
    #
    # @api private
    def determine_visibility
      @reader_visibility = @options[:reader] || @options[:accessor] || :public
      @writer_visibility = @options[:writer] || @options[:accessor] || :public
    end

    # Typecasts an arbitrary value to a DateTime.
    # Handles both Hashes and DateTime instances.
    #
    # @param [#to_mash, #to_s] value
    #   value to be typecast to DateTime
    #
    # @return [DateTime]
    #   DateTime constructed from value
    #
    # @api private
    def typecast_to_datetime(value)
      if value.kind_of?(Hash)
        typecast_hash_to_datetime(value)
      else
        DateTime.parse(value.to_s)
      end
    end

    # Typecasts an arbitrary value to a Date
    # Handles both Hashes and Date instances.
    #
    # @param [#to_mash, #to_s] value
    #   value to be typecast to Date
    #
    # @return [Date]
    #   Date constructed from value
    #
    # @api private
    def typecast_to_date(value)
      if value.kind_of?(Hash)
        typecast_hash_to_date(value)
      else
        Date.parse(value.to_s)
      end
    end

    # Typecasts an arbitrary value to a Time
    # Handles both Hashes and Time instances.
    #
    # @param [#to_mash, #to_s] value
    #   value to be typecast to Time
    #
    # @return [Time]
    #   Time constructed from value
    #
    # @api private
    def typecast_to_time(value)
      if value.kind_of?(Hash)
        typecast_hash_to_time(value)
      else
        Time.parse(value.to_s)
      end
    end

    # Creates a DateTime instance from a Hash with keys :year, :month, :day,
    # :hour, :min, :sec
    #
    # @param [#to_mash] hash
    #   Hash to be typecast to DateTime
    #
    # @return [DateTime]
    #   DateTime constructed from hash
    #
    # @api private
    def typecast_hash_to_datetime(hash)
      DateTime.new(*extract_time(hash))
    rescue ArgumentError
      typecast_hash_to_time(hash).to_datetime
    end

    # Creates a Date instance from a Hash with keys :year, :month, :day
    #
    # @param [#to_mash] hash
    #   Hash to be typecast to Date
    #
    # @return [Date]
    #   Date constructed from hash
    #
    # @api private
    def typecast_hash_to_date(hash)
      Date.new(*extract_time(hash)[0, 3])
    rescue ArgumentError
      # TODO: use Time#to_date once available in Extlib
      time = typecast_hash_to_time(hash)
      Date.new(time.year, time.month, time.day)
    end

    # Creates a Time instance from a Hash with keys :year, :month, :day,
    # :hour, :min, :sec
    #
    # @param [#to_mash] hash
    #   Hash to be typecast to Time
    #
    # @return [Time]
    #   Time constructed from hash
    #
    # @api private
    def typecast_hash_to_time(hash)
      Time.local(*extract_time(hash))
    end

    # Extracts the given args from the hash. If a value does not exist, it
    # uses the value of Time.now.
    #
    # @param [#to_mash] hash
    #   Hash to extract time args from
    #
    # @return [Array]
    #   Extracted values
    #
    # @api private
    def extract_time(hash)
      mash = hash.to_mash
      now  = Time.now

      [ :year, :month, :day, :hour, :min, :sec ].map do |segment|
        mash.fetch(segment, now.send(segment))
      end
    end

    ##
    # Return true if +other+'s is equivalent or equal to +self+'s
    #
    # @param [Property] other
    #   The Property whose attributes are to be compared with +self+'s
    # @param [Symbol] operator
    #   The comparison operator to use to compare the attributes
    #
    # @return [TrueClass, FalseClass]
    #   The result of the comparison of +other+'s attributes with +self+'s
    #
    # @api private
    def cmp?(other, operator)
      unless model.base_model.send(operator, other.model.base_model)
        return false
      end

      unless name.send(operator, other.name)
        return false
      end

      true
    end
  end # class Property
end # module DataMapper
