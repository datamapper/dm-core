# TODO: move paranoid property concerns to a ParanoidModel that is mixed
# into Model when a Paranoid property is used

# TODO: update Model#respond_to? to return true if method_method missing
# would handle the message

module DataMapper
  module Model
    module Property
      Model.append_extensions self

      extend Chainable

      def self.extended(model)
        model.instance_variable_set(:@properties,               {})
        model.instance_variable_set(:@field_naming_conventions, {})
        model.instance_variable_set(:@paranoid_properties,      {})
      end

      chainable do
        def inherited(model)
          model.instance_variable_set(:@properties,               {})
          model.instance_variable_set(:@field_naming_conventions, @field_naming_conventions.dup)
          model.instance_variable_set(:@paranoid_properties,      @paranoid_properties.dup)

          @properties.each do |repository_name, properties|
            model_properties = model.properties(repository_name)
            properties.each { |property| model_properties[property.name] ||= property }
          end

          super
        end
      end

      # Defines a Property on the Resource
      #
      # @param [Symbol] name
      #   the name for which to call this property
      # @param [Type] type
      #   the type to define this property ass
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
        property = DataMapper::Property.new(self, name, type, options)

        repository_name = self.repository_name
        properties      = properties(repository_name)

        properties << property

        # Add property to the other mappings as well if this is for the default
        # repository.
        if repository_name == default_repository_name
          @properties.except(repository_name).each do |repository_name, properties|
            next if properties.named?(name)

            # make sure the property is created within the correct repository scope
            DataMapper.repository(repository_name) do
              properties << DataMapper::Property.new(self, name, type, options)
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
            properties.lazy_context(context) << self
          end
        end

        # add the property to the child classes only if the property was
        # added after the child classes' properties have been copied from
        # the parent
        descendants.each do |descendant|
          descendant.properties(repository_name)[name] ||= property
        end

        create_reader_for(property)
        create_writer_for(property)

        property
      end

      # Gets a list of all properties that have been defined on this Model in
      # the requested repository
      #
      # @param [Symbol, String] repository_name
      #   The name of the repository to use. Uses the default Repository
      #   if none is specified.
      #
      # @return [Array]
      #   A list of Properties defined on this Model in the given Repository
      #
      # @api public
      def properties(repository_name = default_repository_name)
        # TODO: create PropertySet#copy that will copy the properties, but assign the
        # new Relationship objects to a supplied repository and model.  dup does not really
        # do what is needed

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
        properties = PropertySet.new

        descendants.each do |model|
          model.properties(repository_name).each do |property|
            properties[property.name] ||= property
          end
        end

        properties
      end

      # @api private
      def paranoid_properties
        @paranoid_properties
      end

      # @api private
      def set_paranoid_property(name, &block)
        paranoid_properties[name] = block
      end

      # @api private
      def key_conditions(repository, key)
        self.key(repository.name).zip(key.nil? ? [] : key).to_hash
      end

      private

      # defines the reader method for the property
      #
      # @api private
      def create_reader_for(property)
        name                   = property.name.to_s
        reader_visibility      = property.reader_visibility
        instance_variable_name = property.instance_variable_name
        primitive              = property.primitive

        unless resource_method_defined?(name)
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            #{reader_visibility}
            def #{name}
              return #{instance_variable_name} if defined?(#{instance_variable_name})
              #{instance_variable_name} = properties[#{name.inspect}].get(self)
            end
          RUBY
        end

        boolean_reader_name = "#{name}?"

        if primitive == TrueClass && !resource_method_defined?(boolean_reader_name)
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            #{reader_visibility}
            alias #{boolean_reader_name} #{name}
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

        return if resource_method_defined?(writer_name)

        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          #{writer_visibility}
          def #{writer_name}(value)
            properties[#{name.inspect}].set(self, value)
          end
        RUBY
      end

      chainable do
        # @api public
        def method_missing(method, *args, &block)
          if property = properties(repository_name)[method]
            return property
          end

          super
        end
      end
    end # module Property
  end # module Model
end # module DataMapper
