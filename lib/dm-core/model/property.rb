# TODO: update Model#respond_to? to return true if method_method missing
# would handle the message

module DataMapper
  module Model
    module Property
      Model.append_extensions self, DataMapper::Property::Lookup

      def self.extended(model)
        model.instance_variable_set(:@properties,               {})
        model.instance_variable_set(:@field_naming_conventions, {})
      end


      def inherited(model)
        model.instance_variable_set(:@properties,               {})
        model.instance_variable_set(:@field_naming_conventions, @field_naming_conventions.dup)

        @properties.each do |repository_name, properties|
          model_properties = model.properties(repository_name)
          properties.each { |property| model_properties << property }
        end

        super
      end

      # Defines a Property on the Resource
      #
      # @param [Symbol] name
      #   the name for which to call this property
      # @param [Class] type
      #   the ruby type to define this property as
      # @param [Hash(Symbol => String)] options
      #   a hash of available options
      #
      # @return [Property]
      #   the created Property
      #
      # @see Property
      #
      # @api public
      def property(name, type, options = {})
        if TrueClass == type
          raise "#{type} is deprecated, use Boolean instead at #{caller[2]}"
        elsif BigDecimal == type
          raise "#{type} is deprecated, use Decimal instead at #{caller[2]}"
        end

        # if the type can be found within Property then
        # use that class rather than the primitive
        unless klass = DataMapper::Property.determine_class(type)
          raise ArgumentError, "+type+ was #{type.inspect}, which is not a supported type"
        end

        property = klass.new(self, name, options)

        repository_name = self.repository_name
        properties      = properties(repository_name)

        properties << property

        # Add property to the other mappings as well if this is for the default
        # repository.

        if repository_name == default_repository_name
          other_repository_properties = DataMapper::Ext::Hash.except(@properties, default_repository_name)

          other_repository_properties.each do |other_repository_name, properties|
            next if properties.named?(name)

            # make sure the property is created within the correct repository scope
            DataMapper.repository(other_repository_name) do
              properties << klass.new(self, name, options)
            end
          end
        end

        # Add the property to the lazy_loads set for this resources repository
        # only.
        # TODO Is this right or should we add the lazy contexts to all
        # repositories?
        if property.lazy?
          context = options.fetch(:lazy, :default)
          context = :default if context == true

          Array(context).each do |context|
            properties.lazy_context(context) << property
          end
        end

        # add the property to the child classes only if the property was
        # added after the child classes' properties have been copied from
        # the parent
        descendants.each do |descendant|
          descendant.properties(repository_name) << property
        end

        create_reader_for(property)
        create_writer_for(property)

        # FIXME: explicit return needed for YARD to parse this properly
        return property
      end

      # Gets a list of all properties that have been defined on this Model in
      # the requested repository
      #
      # @param [Symbol, String] repository_name
      #   The name of the repository to use. Uses the default Repository
      #   if none is specified.
      #
      # @return [PropertySet]
      #   A list of Properties defined on this Model in the given Repository
      #
      # @api public
      def properties(repository_name = default_repository_name)
        # TODO: create PropertySet#copy that will copy the properties, but assign the
        # new Relationship objects to a supplied repository and model.  dup does not really
        # do what is needed
        repository_name = repository_name.to_sym

        default_repository_name = self.default_repository_name

        @properties[repository_name] ||= if repository_name == default_repository_name
          PropertySet.new
        else
          properties(default_repository_name).dup
        end
      end

      # Gets the list of key fields for this Model in +repository_name+
      #
      # @param [String] repository_name
      #   The name of the Repository for which the key is to be reported
      #
      # @return [Array]
      #   The list of key fields for this Model in +repository_name+
      #
      # @api public
      def key(repository_name = default_repository_name)
        properties(repository_name).key
      end

      # @api public
      def serial(repository_name = default_repository_name)
        key(repository_name).detect { |property| property.serial? }
      end

      # Gets the field naming conventions for this resource in the given Repository
      #
      # @param [String, Symbol] repository_name
      #   the name of the Repository for which the field naming convention
      #   will be retrieved
      #
      # @return [#call]
      #   The naming convention for the given Repository
      #
      # @api public
      def field_naming_convention(repository_name = default_storage_name)
        @field_naming_conventions[repository_name] ||= repository(repository_name).adapter.field_naming_convention
      end

      # @api private
      def properties_with_subclasses(repository_name = default_repository_name)
        properties = properties(repository_name).dup

        descendants.each do |model|
          model.properties(repository_name).each do |property|
            properties << property
          end
        end

        properties
      end

      # @api private
      def key_conditions(repository, key)
        Hash[ self.key(repository.name).zip(key.nil? ? [] : key) ]
      end

    private

      # Defines the anonymous module that is used to add properties.
      # Using a single module here prevents having a very large number
      # of anonymous modules, where each property has their own module.
      # @api private
      def property_module
        @property_module ||= begin
          mod = Module.new
          class_eval do
            include mod
          end
          mod
        end
      end

      # defines the reader method for the property
      #
      # @api private
      def create_reader_for(property)
        name                   = property.name.to_s
        reader_visibility      = property.reader_visibility
        instance_variable_name = property.instance_variable_name
        property_module.module_eval <<-RUBY, __FILE__, __LINE__ + 1
          #{reader_visibility}
          def #{name}
            return #{instance_variable_name} if defined?(#{instance_variable_name})
            property = properties[#{name.inspect}]
            #{instance_variable_name} = property ? persistence_state.get(property) : nil
          end
        RUBY

        boolean_reader_name = "#{name}?"

        if property.kind_of?(DataMapper::Property::Boolean)
          property_module.module_eval <<-RUBY, __FILE__, __LINE__ + 1
            #{reader_visibility}
            def #{boolean_reader_name}
              #{name}
            end
          RUBY
        end
      end

      # defines the setter for the property
      #
      # @api private
      def create_writer_for(property)
        name              = property.name
        writer_visibility = property.writer_visibility

        writer_name = "#{name}="
        property_module.module_eval <<-RUBY, __FILE__, __LINE__ + 1
          #{writer_visibility}
          def #{writer_name}(value)
            property = properties[#{name.inspect}]
            value    = property.typecast(value)
            self.persistence_state = persistence_state.set(property, value)
            persistence_state.get(property)
          end
        RUBY
      end

      # @api public
      def method_missing(method, *args, &block)
        if property = properties(repository_name)[method]
          return property
        end

        super
      end
    end # module Property
  end # module Model
end # module DataMapper
