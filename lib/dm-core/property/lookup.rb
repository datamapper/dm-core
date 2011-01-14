module DataMapper
  class Property
    module Lookup

      protected

      #
      # Provides transparent access to the Properties defined in
      # {Property}.
      #
      # @param [Symbol] name
      #   The name of the property to lookup.
      #
      # @return [Property]
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
        Property.find_class(name.to_s) || super
      end
    end
  end
end
