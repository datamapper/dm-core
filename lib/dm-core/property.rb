require 'dm-core/resource'
require 'dm-core/query'

module DataMapper
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
  #   in your models, DataMapper plays well with legacy databases, and shares
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
  #     property :title,   String,  :required => true  # Cannot be null
  #     property :publish, Boolean, :default => false  # Default value for new records is false
  #   end
  #
  # By default, DataMapper supports the following primitive (Ruby) types
  # also called core properties:
  #
  # * Boolean
  # * Class (datastore primitive is the same as String. Used for Inheritance)
  # * Date
  # * DateTime
  # * Decimal
  # * Float
  # * Integer
  # * Object (marshalled out during serialization)
  # * String (default length is 50)
  # * Text (limit of 65k characters by default)
  # * Time
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
  # instance, DataMapper::Property::Text fields are lazy loading by default,
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
  #    property :title, String, :required => true
  #      # => infers 'validates_present :title
  #
  #    property :email, String, :format => :email_address
  #      # => infers 'validates_format :email, :with => :email_address
  #
  #    property :title, String, :length => 255, :required => true
  #      # => infers both 'validates_length' as well as
  #      #    'validates_present'
  #      #    better: property :title, String, :length => 1..255
  #
  #  end
  #
  # This functionality is available with the dm-validations gem. For more information
  # about validations, check the documentation for dm-validations.
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
  # == Embedded Values (not implemented yet)
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
  #  :allow_nil           if true, property may have a nil value on save
  #
  #  :key                 name of the key associated with this property.
  #
  #  :field               field in the data-store which the property corresponds to
  #
  #  :length              string field length
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
  #                       Default is nil for Float type and 10 for BigDecimal
  #
  #  All other keys you pass to +property+ method are stored and available
  #  as options[:extra_keys].
  #
  # == Overriding default Property options
  #
  # There is the ability to reconfigure a Property and it's subclasses by explicitly
  # setting a value in the Property, eg:
  #
  #   # set all String properties to have a default length of 255
  #   DataMapper::Property::String.length(255)
  #
  #   # set all Boolean properties to not allow nil (force true or false)
  #   DataMapper::Property::Boolean.allow_nil(false)
  #
  #   # set all properties to be required by default
  #   DataMapper::Property.required(true)
  #
  #   # turn off auto-validation for all properties by default
  #   DataMapper::Property.auto_validation(false)
  #
  #   # set all mutator methods to be private by default
  #   DataMapper::Property.writer(false)
  #
  # Please note that this has no effect when a subclass has explicitly
  # defined it's own option. For example, setting the String length to
  # 255 will not affect the Text property even though it inherits from
  # String, because it sets it's own default length to 65535.
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
    module PassThroughLoadDump
      # @api semipublic
      def load(value)
        return if value.nil?
        typecast(value)
      end

      # Stub instance method for dumping
      #
      # @param value     [Object, nil]    value to dump
      #
      # @return [Object] Dumped object
      #
      # @api semipublic
      def dump(value)
        value
      end
    end

    include DataMapper::Assertions
    include Subject
    extend Chainable
    extend Equalizer

    equalize :model, :name

    PRIMITIVES = [
      TrueClass,
      ::String,
      ::Float,
      ::Integer,
      ::BigDecimal,
      ::DateTime,
      ::Date,
      ::Time,
      ::Class
    ].to_set.freeze

    OPTIONS = [
      :accessor, :reader, :writer,
      :lazy, :default, :key, :field,
      :index, :unique_index,
      :unique, :allow_nil, :allow_blank, :required
    ]

    # Possible :visibility option values
    VISIBILITY_OPTIONS = [ :public, :protected, :private ].to_set.freeze

    # Invalid property names
    INVALID_NAMES = (Resource.instance_methods + Resource.private_instance_methods + Query::OPTIONS.to_a).map { |name| name.to_s }.freeze

    attr_reader :primitive, :model, :name, :instance_variable_name,
      :reader_visibility, :writer_visibility, :options,
      :default, :repository_name, :allow_nil, :allow_blank, :required

    class << self
      extend Deprecate

      deprecate :all_descendants, :descendants

      # @api semipublic
      def determine_class(type)
        return type if type < DataMapper::Property::Object
        find_class(DataMapper::Inflector.demodulize(type.name))
      end

      # @api private
      def demodulized_names
        @demodulized_names ||= {}
      end

      # @api semipublic
      def find_class(name)
        klass   = demodulized_names[name]
        klass ||= const_get(name) if const_defined?(name)
        klass
      end

      # @api public
      def descendants
        @descendants ||= DescendantSet.new
      end

      # @api private
      def inherited(descendant)
        # Descendants is a tree rooted in DataMapper::Property that tracks
        # inheritance.  We pre-calculate each comparison value (demodulized
        # class name) to achieve a Hash[]-time lookup, rather than walk the
        # entire descendant tree and calculate names on-demand (expensive,
        # redundant).
        #
        # Since the algorithm relegates property class name lookups to a flat
        # namespace, we need to ensure properties defined outside of DM don't
        # override built-ins (Serial, String, etc) by merely defining a property
        # of a same name.  We avoid this by only ever adding to the lookup
        # table.  Given that DM loads its own property classes first, we can
        # assume that their names are "reserved" when added to the table.
        #
        # External property authors who want to provide "replacements" for
        # builtins (e.g. in a non-DM-supported adapter) should follow the
        # convention of wrapping those properties in a module, and include'ing
        # the module on the model class directly.  This bypasses the DM-hooked
        # const_missing lookup that would normally check this table.
        descendants << descendant

        Property.demodulized_names[DataMapper::Inflector.demodulize(descendant.name)] ||= descendant

        # inherit accepted options
        descendant.accepted_options.concat(accepted_options)

        # inherit the option values
        options.each { |key, value| descendant.send(key, value) }
      end

      # @api public
      def accepted_options
        @accepted_options ||= []
      end

      # @api public
      def accept_options(*args)
        accepted_options.concat(args)

        # create methods for each new option
        args.each do |property_option|
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def self.#{property_option}(value = Undefined)                         # def self.unique(value = Undefined)
              return @#{property_option} if value.equal?(Undefined)                #   return @unique if value.equal?(Undefined)
              descendants.each do |descendant|                                     #   descendants.each do |descendant|
                unless descendant.instance_variable_defined?(:@#{property_option}) #     unless descendant.instance_variable_defined?(:@unique)
                  descendant.#{property_option}(value)                             #       descendant.unique(value)
                end                                                                #     end
              end                                                                  #   end
              @#{property_option} = value                                          #   @unique = value
            end                                                                    # end
          RUBY
        end

        descendants.each { |descendant| descendant.accepted_options.concat(args) }
      end

      # @api private
      def nullable(*args)
        # :required is preferable to :allow_nil, but :nullable maps precisely to :allow_nil
        raise "#nullable is deprecated, use #required instead (#{caller.first})"
      end

      # Gives all the options set on this property
      #
      # @return [Hash] with all options and their values set on this property
      #
      # @api public
      def options
        options = {}
        accepted_options.each do |method|
          value = send(method)
          options[method] = value unless value.nil?
        end
        options
      end
    end

    accept_options :primitive, *Property::OPTIONS

    # A hook to allow properties to extend or modify the model it's bound to.
    # Implementations are not supposed to modify the state of the property
    # class, and should produce no side-effects on the property instance.
    def bind
      # no op
    end

    # Supplies the field in the data-store which the property corresponds to
    #
    # @return [String] name of field in data-store
    #
    # @api semipublic
    def field(repository_name = nil)
      if repository_name
        raise "Passing in +repository_name+ to #{self.class}#field is deprecated (#{caller.first})"
      end

      # defer setting the field with the adapter specific naming
      # conventions until after the adapter has been setup
      @field ||= model.field_naming_convention(self.repository_name).call(self).freeze
    end

    # Returns true if property is unique. Serial properties and keys
    # are unique by default.
    #
    # @return [Boolean]
    #   true if property has uniq index defined, false otherwise
    #
    # @api public
    def unique?
      !!@unique
    end

    # Returns index name if property has index.
    #
    # @return [Boolean, Symbol, Array]
    #   returns true if property is indexed by itself
    #   returns a Symbol if the property is indexed with other properties
    #   returns an Array if the property belongs to multiple indexes
    #   returns false if the property does not belong to any indexes
    #
    # @api public
    attr_reader :index

    # Returns true if property has unique index. Serial properties and
    # keys are unique by default.
    #
    # @return [Boolean, Symbol, Array]
    #   returns true if property is indexed by itself
    #   returns a Symbol if the property is indexed with other properties
    #   returns an Array if the property belongs to multiple indexes
    #   returns false if the property does not belong to any indexes
    #
    # @api public
    attr_reader :unique_index

    # Returns whether or not the property is to be lazy-loaded
    #
    # @return [Boolean]
    #   true if the property is to be lazy-loaded
    #
    # @api public
    def lazy?
      @lazy
    end

    # Returns whether or not the property is a key or a part of a key
    #
    # @return [Boolean]
    #   true if the property is a key or a part of a key
    #
    # @api public
    def key?
      @key
    end

    # Returns whether or not the property is "serial" (auto-incrementing)
    #
    # @return [Boolean]
    #   whether or not the property is "serial"
    #
    # @api public
    def serial?
      @serial
    end

    # Returns whether or not the property must be non-nil and non-blank
    #
    # @return [Boolean]
    #   whether or not the property is required
    #
    # @api public
    def required?
      @required
    end

    # Returns whether or not the property can accept 'nil' as it's value
    #
    # @return [Boolean]
    #   whether or not the property can accept 'nil'
    #
    # @api public
    def allow_nil?
      @allow_nil
    end

    # Returns whether or not the property can be a blank value
    #
    # @return [Boolean]
    #   whether or not the property can be blank
    #
    # @api public
    def allow_blank?
      @allow_blank
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
      get!(resource)
    end

    # Fetch the ivar value in the resource
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

    # Provides a standardized setter method for the property
    #
    # @param [Resource] resource
    #   the resource to get the value from
    # @param [Object] value
    #   the value to set in the resource
    #
    # @return [Object]
    #   +value+ after being typecasted according to this property's primitive
    #
    # @raise [ArgumentError] "+resource+ should be a Resource, but was ...."
    #
    # @api private
    def set(resource, value)
      set!(resource, typecast(value))
    end

    # Set the ivar value in the resource
    #
    # @param [Resource] resource
    #   the resource to set
    # @param [Object] value
    #   the value to set in the resource
    #
    # @return [Object]
    #   the value set in the resource
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
    # @return [Boolean]
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
      return if loaded?(resource)
      resource.__send__(:lazy_load, lazy_load_properties)
    end

    # @api private
    def lazy_load_properties
      @lazy_load_properties ||=
        begin
          properties = self.properties
          properties.in_context(lazy? ? [ self ] : properties.defaults)
        end
    end

    # @api private
    def properties
      @properties ||= model.properties(repository_name)
    end

    # @api semipublic
    def typecast(value)
      if value.nil? || primitive?(value)
        value
      elsif respond_to?(:typecast_to_primitive)
        typecast_to_primitive(value)
      end
    end

    # Test the value to see if it is a valid value for this Property
    #
    # @param [Object] loaded_value
    #   the value to be tested
    #
    # @return [Boolean]
    #   true if the value is valid
    #
    # @api semipulic
    def valid?(value, negated = false)
      dumped_value = dump(value)

      if required? && dumped_value.nil?
        negated || false
      else
        primitive?(dumped_value) || (dumped_value.nil? && (allow_nil? || negated))
      end
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

    # Test a value to see if it matches the primitive type
    #
    # @param [Object] value
    #   value to test
    #
    # @return [Boolean]
    #   true if the value is the correct type
    #
    # @api semipublic
    def primitive?(value)
      value.kind_of?(primitive)
    end

    chainable do
      def self.new(model, name, options = {})
        super
      end
    end

    protected

    # @api semipublic
    def initialize(model, name, options = {})
      options = options.to_hash.dup

      if INVALID_NAMES.include?(name.to_s)
        raise ArgumentError, "+name+ was #{name.inspect}, which cannot be used as a property name since it collides with an existing method or a query option"
      end

      assert_valid_options(options)

      predefined_options = self.class.options

      @repository_name        = model.repository_name
      @model                  = model
      @name                   = name.to_s.chomp('?').to_sym
      @options                = predefined_options.merge(options).freeze
      @instance_variable_name = "@#{@name}".freeze

      @primitive = self.class.primitive
      @field     = @options[:field].freeze unless @options[:field].nil?
      @default   = @options[:default]

      @serial       = @options.fetch(:serial,       false)
      @key          = @options.fetch(:key,          @serial)
      @unique       = @options.fetch(:unique,       @key ? :key : false)
      @required     = @options.fetch(:required,     @key)
      @allow_nil    = @options.fetch(:allow_nil,    !@required)
      @allow_blank  = @options.fetch(:allow_blank,  !@required)
      @index        = @options.fetch(:index,        false)
      @unique_index = @options.fetch(:unique_index, @unique)
      @lazy         = @options.fetch(:lazy,         false) && !@key

      determine_visibility

      bind
    end

    # @api private
    def assert_valid_options(options)
      keys = options.keys

      if (unknown_keys = keys - self.class.accepted_options).any?
        raise ArgumentError, "options #{unknown_keys.map { |key| key.inspect }.join(' and ')} are unknown"
      end

      options.each do |key, value|
        boolean_value = value == true || value == false

        case key
          when :field
            assert_kind_of "options[:#{key}]", value, ::String

          when :default
            if value.nil?
              raise ArgumentError, "options[:#{key}] must not be nil"
            end

          when :serial, :key, :allow_nil, :allow_blank, :required, :auto_validation
            unless boolean_value
              raise ArgumentError, "options[:#{key}] must be either true or false"
            end

            if key == :required && (keys.include?(:allow_nil) || keys.include?(:allow_blank))
              raise ArgumentError, 'options[:required] cannot be mixed with :allow_nil or :allow_blank'
            end

          when :index, :unique_index, :unique, :lazy
            unless boolean_value || value.kind_of?(Symbol) || (value.kind_of?(Array) && value.any? && value.all? { |val| val.kind_of?(Symbol) })
              raise ArgumentError, "options[:#{key}] must be either true, false, a Symbol or an Array of Symbols"
            end

          when :length
            assert_kind_of "options[:#{key}]", value, Range, ::Integer

          when :size, :precision, :scale
            assert_kind_of "options[:#{key}]", value, ::Integer

          when :reader, :writer, :accessor
            assert_kind_of "options[:#{key}]", value, Symbol

            unless VISIBILITY_OPTIONS.include?(value)
              raise ArgumentError, "options[:#{key}] must be #{VISIBILITY_OPTIONS.join(' or ')}"
            end
        end
      end
    end

    # Assert given visibility value is supported.
    #
    # Will raise ArgumentError if this Property's reader and writer
    # visibilities are not included in VISIBILITY_OPTIONS.
    #
    # @return [undefined]
    #
    # @raise [ArgumentError] "property visibility must be :public, :protected, or :private"
    #
    # @api private
    def determine_visibility
      default_accessor = @options.fetch(:accessor, :public)

      @reader_visibility = @options.fetch(:reader, default_accessor)
      @writer_visibility = @options.fetch(:writer, default_accessor)
    end
  end # class Property
end
