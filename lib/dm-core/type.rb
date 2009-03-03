module DataMapper

  # = Types
  # Provides means of writing custom types for properties. Each type is based
  # on a ruby primitive and handles its own serialization and materialization,
  # and therefore is responsible for providing those methods.
  #
  # To see complete list of supported types, see documentation for
  # Property::TYPES. dm-types library provides less common
  # types such as ip address, uuid, json, yaml, uri, slug, version,
  # file path, bcrypt hash and so forth.
  #
  # == Defining new Types
  # To define a new type, subclass DataMapper::Type, pick ruby primitive, and
  # set the options for this type.
  #
  #   class MyType < DataMapper::Type
  #     primitive String
  #     size 10
  #   end
  #
  # Following this, you will be able to use MyType as a type for any given
  # property. If special materialization and serialization is required,
  # override the class methods
  #
  #   class MyType < DataMapper::Type
  #     primitive String
  #     size 10
  #
  #     def self.dump(value, property)
  #       <work some magic>
  #     end
  #
  #     def self.load(value)
  #       <work some magic>
  #     end
  #   end
  class Type
    PROPERTY_OPTIONS = ::DataMapper::Property::PROPERTY_OPTIONS

    class << self

      def configure(primitive_type, options)
        @_primitive_type = primitive_type
        @_options = options

        def self.inherited(base)
          base.primitive @_primitive_type

          @_options.each do |k, v|
            base.send(k, v)
          end
        end

        self
      end

      # The Ruby primitive type to use as basis for this type. See
      # Property::TYPES for list of types.
      #
      # @param primitive<Class, nil>
      #   The class for the primitive. If nil is passed in, it returns the
      #   current primitive
      #
      # @return <Class> if the <primitive> param is nil, return the current primitive.
      #
      # @api public
      def primitive(primitive = nil)
        return @primitive if primitive.nil?
        @primitive = primitive
      end

      # Load Property options
      PROPERTY_OPTIONS.each do |property_option|
        self.class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{property_option}(*args)                                  # def unique(*args)
            if args.any?                                                 #   if args.any?
              @#{property_option} = args.first                           #     @unique = args.first
            else                                                         #   else
              defined?(@#{property_option}) ? @#{property_option} : nil  #     defined?(@unique) ? @unique : nil
            end                                                          #   end
          end                                                            # end
        RUBY
      end

      # Gives all the options set on this type
      #
      # @return <Hash> with all options and their values set on this type
      #
      # @api public
      def options
        options = {}
        PROPERTY_OPTIONS.each do |method|
          next if (value = send(method)).nil?
          options[method] = value
        end
        options
      end
    end

    # Stub instance method for dumping
    #
    # @param value<Object, nil>       the value to dump
    # @param property<Property, nil>  the property the type is being used by
    #
    # @return <Object> Dumped object
    #
    # @api public
    def self.dump(value, property)
      value
    end

    # Stub instance method for loading
    #
    # @param value<Object, nil>       the value to serialize
    # @param property<Property, nil>  the property the type is being used by
    #
    # @return <Object> Serialized object. Must be the same type as the Ruby primitive
    #
    # @api public
    def self.load(value, property)
      value
    end

    # A hook to allow types to extend or modify property it's bound to.
    # Implementations are not supposed to modify the state of the type class, and
    # should produce no side-effects on the type class.
    def self.bind(property)
      # no op
    end

  end # class Type

  def self.Type(primitive_type, options = {})
    warn "DataMapper.Type(#{primitive_type}) is deprecated, specify the primitive and options explicitly"
    Class.new(Type).configure(primitive_type, options)
  end

end # module DataMapper
