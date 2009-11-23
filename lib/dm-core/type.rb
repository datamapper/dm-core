module DataMapper

  # = Types
  # Provides means of writing custom types for properties. Each type is based
  # on a ruby primitive and handles its own serialization and materialization,
  # and therefore is responsible for providing those methods.
  #
  # To see complete list of supported types, see documentation for
  # Property::PRIMITIVES. dm-types library provides less common
  # types such as ip address, uuid, json, yaml, uri, slug, version,
  # file path, bcrypt hash and so forth.
  #
  # == Defining new Types
  # To define a new type, subclass DataMapper::Type, pick ruby primitive, and
  # set the options for this type.
  #
  #   class LowerCase < DataMapper::Type
  #     primitive        String
  #     auto_validation  true
  #     length           255
  #   end
  #
  # Following this, you will be able to use LowerCase as a type for any given
  # property. If special materialization and serialization is required,
  # override the class methods
  #
  #   class LowerCase < DataMapper::Type
  #     primitive        String
  #     auto_validation  true
  #     length           255
  #
  #     def self.dump(value, property)
  #       return nil unless value
  #       value.to_s.downcase
  #     end
  #
  #     def self.load(value)
  #       value
  #     end
  #   end
  #
  # Properties of LowerCase type now will downcase it's values before
  # it is persisted to the storage.
  #
  # One more real world example from dm-types library is a JSON type
  # that stores values serialized as JSON, and often useful for embedded
  # values:
  #
  #
  # module DataMapper
  #   module Types
  #     class Json < DataMapper::Type
  #       primitive String
  #       length    65535
  #       lazy      true
  #
  #       def self.load(value, property)
  #         if value.nil?
  #           nil
  #         elsif value.kind_of?(String)
  #           ::JSON.load(value)
  #         else
  #           raise ArgumentError, '+value+ of a property of JSON type must be nil or a String'
  #         end
  #       end
  #
  #       def self.dump(value, property)
  #         if value.nil? || value.kind_of?(String)
  #           value
  #         else
  #           ::JSON.dump(value)
  #         end
  #       end
  #
  #       def self.typecast(value, property)
  #         if value.nil? || value.kind_of?(Array) || value.kind_of?(Hash)
  #           value
  #         else
  #           ::JSON.load(value.to_s)
  #         end
  #       end
  #     end # class Json
  #     JSON = Json
  #   end # module Types
  # end # module DataMapper
  class Type
    # Until cooperation of Property and Type does not change, each must
    # have a separate list of options, because plugins (ex.: dm-validations)
    # may want to extend one or the other, and expects no side effects
    PROPERTY_OPTIONS = [
      :accessor, :reader, :writer,
      :lazy, :default, :key, :serial, :field, :size, :length,
      :format, :index, :unique_index, :auto_validation,
      :validates, :unique, :precision, :scale, :min, :max,
      :allow_nil, :allow_blank, :required
    ]

    class << self
      # @api private
      def configure(primitive_type, options)
        warn "DataMapper.Type.configure is deprecated, specify the primitive and options explicitly (#{caller[0]})"

        @_primitive_type = primitive_type
        @_options = options

        def self.inherited(base)
          base.primitive @_primitive_type
          @_options.each { |key, value| base.send(key, value) }
        end

        self
      end

      # Ruby primitive type to use as basis for this type. See
      # Property::PRIMITIVES for list of types.
      #
      # @param primitive [Class, nil]
      #   The class for the primitive. If nil is passed in, it returns the
      #   current primitive
      #
      # @return [Class] if the <primitive> param is nil, return the current primitive.
      #
      # @api public
      def primitive(primitive = nil)
        return @primitive if primitive.nil?
        @primitive = primitive

        return unless @primitive.respond_to?(:options)
        options = @primitive.options

        return unless options.respond_to?(:each)

        # inherit the options from the primitive if any
        options.each do |key, value|
          send(key, value) unless send(key)
        end
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

      def nullable(value)
        # :required is preferable to :allow_nil, but :nullable maps precisely to :allow_nil
        warn "#nullable is deprecated, use #required instead (#{caller[0]})"
        allow_nil(value)
      end

      # Gives all the options set on this type
      #
      # @return [Hash] with all options and their values set on this type
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
    # @param value     [Object, nil]    value to dump
    # @param property  [Property, nil]  property the type is being used by
    #
    # @return [Object] Dumped object
    #
    # @api public
    def self.dump(value, property)
      value
    end

    # Stub instance method for loading
    #
    # @param value     [Object, nil]    value to serialize
    # @param property  [Property, nil]  property the type is being used by
    #
    # @return [Object] Serialized object. Must be the same type as the Ruby primitive
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

  # @deprecated
  def self.Type(primitive_type, options = {})
    warn "DataMapper.Type(#{primitive_type}) is deprecated, specify the primitive and options explicitly (#{caller[0]})"
    Class.new(Type).configure(primitive_type, options)
  end

end # module DataMapper
