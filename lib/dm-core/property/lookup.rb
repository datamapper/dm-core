module DataMapper
  class Property
    module Lookup

      protected

      #
      # Provides transparent access to the Properties defined in
      # {Property}. It also provides access to the legacy {Types} namespace.
      #
      # @param [Symbol] name
      #   The name of the property to lookup.
      #
      # @return [Property, Type]
      #   The property with the given name.
      #
      # @raise [NameError]
      #   The property could not be found.
      #
      # @api private
      #
      # @since 1.0.1
      #
      def const_missing(name)
        if const = Property.find_class(name.to_s)
          return const
        end

        # only check within DataMapper::Types, if it was loaded.
        if DataMapper.const_defined?(:Types)
          if DataMapper::Types.const_defined?(name)
            type = DataMapper::Types.const_get(name)

            return type if type < DataMapper::Type
          end
        end

        super
      end
    end
  end
end
