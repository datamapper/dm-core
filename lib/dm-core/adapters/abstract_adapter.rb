module DataMapper
  module Adapters
    # Specific adapters extend this class and implement
    # methods for creating, reading, updating and deleting records.
    #
    # Adapters may only implement method for reading or (less common case)
    # writing. Read only adapter may be useful when one needs to work
    # with legacy data that should not be changed or web services that
    # only provide read access to data (from Wordnet and Medline to
    # Atom and RSS syndication feeds)
    #
    # Note that in case of adapters to relational databases it makes
    # sense to inherit from DataObjectsAdapter class.
    class AbstractAdapter
      include Extlib::Assertions
      extend Extlib::Assertions

      # Adapter name. Note that when you use
      #
      # DataMapper.setup(:default, 'postgres://postgres@localhost/dm_core_test')
      #
      # then adapter name is currently be set to is :default
      #
      # @api semipublic
      attr_reader :name

      # Options with which adapter was set up
      #
      # @api semipublic
      attr_reader :options

      # A callable object that implements naming
      # convention for resources and storages
      #
      # @api semipublic
      attr_accessor :resource_naming_convention

      # A callable object that implements naming
      # convention for properties and storage fields
      #
      # @api semipublic
      attr_accessor :field_naming_convention

      # Persists one or many new resources
      # Adapters provide specific implementation of this method
      #
      # @param [Enumerable(Resource)] resources
      #   The list of resources (model instances) to create
      #
      # @return [Integer]
      #   The number of records that were actually saved into the data-store
      #
      # @api semipublic
      def create(resources)
        raise NotImplementedError, "#{self.class}#create not implemented"
      end

      # Reads one or many resources from storage
      # Adapters provide specific implementation of this method
      #
      # @api semipublic
      def read(query)
        raise NotImplementedError, "#{self.class}#read not implemented"
      end

      # Updates one or many existing resources
      # Adapters provide specific implementation of this method
      #
      # @param [Hash(Property => Object)] attributes
      #   hash of attribute values to set, keyed by Property
      # @param [Collection] collection
      #   collection of records to be updated
      #
      # @return [Integer]
      #   the number of records updated
      #
      # @api semipublic
      def update(attributes, collection)
        raise NotImplementedError, "#{self.class}#update not implemented"
      end

      # Deletes one or many existing resources
      # Adapters provide specific implementation of this method
      #
      # @param [Collection] collection
      #   collection of records to be deleted
      #
      # @return [Integer]
      #   the number of records deleted
      #
      # @api semipublic
      def delete(collection)
        raise NotImplementedError, "#{self.class}#delete not implemented"
      end

      ##
      # Compares another AbstractAdapter for equality
      #
      # AbstractAdapter is equal to +other+ if they are the same object (identity)
      # or if they are of the same class and have the same name
      #
      # @param [AbstractAdapter] other
      #   the other AbstractAdapter to compare with
      #
      # @return [TrueClass, FalseClass]
      #   true if they are equal, false if not
      #
      # @api public
      def eql?(other)
        if equal?(other)
          return true
        end

        unless instance_of?(other.class)
          return false
        end

        cmp?(other, :eql?)
      end

      ##
      # Compares another AbstractAdapter for equivalency
      #
      # AbstractAdapter is equal to +other+ if they are the same object (identity)
      # or if they both have the same name
      #
      # @param [AbstractAdapter] other
      #   the other AbstractAdapter to compare with
      #
      # @return [TrueClass, FalseClass]
      #   true if they are equal, false if not
      #
      # @api public
      def ==(other)
        if equal?(other)
          return true
        end

        unless other.respond_to?(:name)
          return false
        end

        unless other.respond_to?(:options)
          return false
        end

        unless other.respond_to?(:resource_naming_convention)
          return false
        end

        unless other.respond_to?(:field_naming_convention)
          return false
        end

        cmp?(other, :==)
      end

      protected

      # TODO: document
      # @api semipublic
      def initialize_identity_field(resource, next_id)
        if identity_field = resource.model.identity_field(name)
          identity_field.set!(resource, next_id)
          # TODO: replace above with this, once
          # specs can handle random, non-sequential ids
          #identity_field.set!(resource, rand(2**32))
        end
      end

      # TODO: document
      # @api semipublic
      def attributes_as_fields(attributes)
        attributes.map { |property, value| [ property.field, value ] }.to_hash
      end

      # TODO: document
      # @api semipublic
      def foreign_key_conditions(comparison)
        relationship = comparison.subject
        sources      = Array(comparison.value)
        slug         = comparison.class.slug

        source_key = relationship.source_key
        target_key = relationship.target_key

        if relationship.source_key.size == 1 && relationship.target_key.size == 1
          source_key = source_key.first
          target_key = target_key.first

          source_values = sources.map { |resource| target_key.get!(resource) }

          if source_values.size > 1
            Query::Conditions::Comparison.new(slug, source_key, source_values)
          else
            Query::Conditions::Comparison.new(slug == :in ? :eql : slug, source_key, source_values.first)
          end
        else
          or_operation = Query::Conditions::Operation.new(:or)

          sources.each do |source|
            source_values = target_key.get!(source)

            and_operation = Query::Conditions::Operation.new(:and)

            source_key.zip(source_values) do |property, value|
              and_operation << Query::Conditions::Comparison.new(slug == :in ? :eql : slug, property, value)
            end

            or_operation << and_operation
          end

          or_operation
        end
      end

      private

      ##
      # Instantiate an Adapter by passing it a Repository
      # connection string for configuration.
      #
      # Also sets up default naming conventions for resources
      # and properties (fields)
      #
      # @api semipublic
      def initialize(name, options)
        assert_kind_of 'name', name, Symbol

        @name                       = name
        @options                    = options.dup.freeze
        @resource_naming_convention = NamingConventions::Resource::UnderscoredAndPluralized
        @field_naming_convention    = NamingConventions::Field::Underscored
      end

      # TODO: document
      # @api private
      def cmp?(other, operator)
        unless name.send(operator, other.name)
          return false
        end

        unless options.send(operator, other.options)
          return false
        end

        unless resource_naming_convention.send(operator, other.resource_naming_convention)
          return false
        end

        unless field_naming_convention.send(operator, other.field_naming_convention)
          return false
        end

        true
      end
    end # class AbstractAdapter

    const_added(:AbstractAdapter)
  end # module Adapters
end # module DataMapper
