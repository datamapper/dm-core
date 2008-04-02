module DataMapper

  # :include:/QUICKLINKS
  #
  # = Types
  # Provides means of writing custom types for properties. Each type is based
  # on a ruby primitive and handles its own serialization and materialization,
  # and therefore is responsible for providing those methods.
  #
  # To see complete list of supported types, see documentation for
  # DataMapper::Property::TYPES
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
  #     def self.materialize(value)
  #       <work some magic>
  #     end
  #
  #     def self.serialize(value)
  #       <work some magic>
  #     end
  #   end
  class Type
    PROPERTY_OPTIONS = [
      :public, :protected, :private, :accessor, :reader, :writer,
      :lazy, :default, :nullable, :key, :serial, :field, :size, :length,
      :format, :index, :check, :ordinal, :auto_validation, :validation_context,
      :lock, :track
    ]

    PROPERTY_OPTION_ALIASES = {
      :size => [ :length ]
    }

    class << self

      def configure(primitive_type, options)
        @_primitive_type = primitive_type
        @_options = options

        def self.inherited(klass)
          klass.primitive @_primitive_type

          @_options.each do |k, v|
            klass.send(k, v)
          end
        end

        self
      end

      #attr_accessor :primitive #map to Ruby type

      # The Ruby primitive type to use as basis for this type. See
      # DataMapper::Property::TYPES for list of types.
      #
      # ==== Parameters
      # primitive<Class, nil>::
      #   The class for the primitive. If nil is passed in, it returns the
      #   current primitive
      #
      # ==== Returns
      # Class:: if the <primitive> param is nil, return the current primitive.
      #
      # @public
      def primitive(primitive = nil)
        return @primitive if primitive.nil?

        @primitive = primitive
      end

      #load DataMapper::Property options
      PROPERTY_OPTIONS.each do |property_option|
        self.class_eval <<-EOS
        def #{property_option}(arg = nil)
          return @#{property_option} if arg.nil?

          @#{property_option} = arg
        end
        EOS
      end

      #create property aliases
      PROPERTY_OPTION_ALIASES.each do |property_option, aliases|
        aliases.each do |ali|
          self.class_eval <<-EOS
          def #{ali}(arg = nil)
            #{property_option}(arg)
          end
          EOS
        end
      end

      # Gives all the options set on this type
      #
      # ==== Returns
      # Hash:: with all options and their values set on this type
      #
      # @public
      def options
        PROPERTY_OPTIONS.inject({}) do |options, method|
          value = send(method)
          options[method.to_sym] = value unless value.nil?; options
        end
      end
    end

    # Stub instance method for materialization
    #
    # ==== Parameters
    # value<Object, nil>::
    #   The value to materialize
    #
    # ==== Returns
    # Object:: Materialized object
    #
    #
    # @public
    def self.dump(value)
      raise NotImplementedError
    end

    # Stub instance method for serialization
    #
    # ==== Parameters
    # value<Object, nil>::
    #   The value to serialize
    #
    # ==== Returns
    # Object:: Serialized object. Must be the same type as the ruby primitive
    #
    #
    # @public
    def self.load(value)
      raise NotImplementedError
    end

  end #class Type

  def self.Type(primitive_type, options = {})
    Class.new(Type).configure(primitive_type, options)
  end

end #module DataMapper