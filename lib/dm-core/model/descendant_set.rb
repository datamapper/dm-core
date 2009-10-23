module DataMapper
  module Model
    class DescendantSet
      include Enumerable

      # Append a model as a descendant
      #
      # @param [Model] model
      #   the descendant model
      #
      # @return [DescendantSet]
      #   self
      #
      # @api private
      def <<(model)
        @descendants << model unless @descendants.include?(model)
        @ancestors   << model if @ancestors
        self
      end

      # Iterate over each descendant
      #
      # @yield [model]
      #   iterate over each descendant
      # @yieldparam [Model] model
      #   the descendant model
      #
      # @return [DescendantSet]
      #   self
      #
      # @api private
      def each
        @descendants.each { |model| yield model }
        self
      end

      # Remove a descendant
      #
      # Also removed the descendant from the ancestors.
      #
      # @param [Model] model
      #   the model to remove
      #
      # @return [Model, nil]
      #   the model is return if it is a descendant
      #
      # @api private
      def delete(model)
        @ancestors.delete(model) if @ancestors
        @descendants.delete(model)
      end

      # Return an Array representation of descendants
      #
      # @return [Array]
      #   the descendants
      #
      # @api private
      def to_ary
        @descendants.dup
      end

      private

      # Initialize a DescendantSet instance
      #
      # @param [Model] model
      #   the base model
      # @param [DescendantSet] ancestors
      #   the ancestors to notify when a descendant is added
      #
      # @api private
      def initialize(model = nil, ancestors = nil)
        @descendants = []
        @ancestors   = ancestors

        @descendants << model if model
      end
    end
  end
end
