require 'dm-core/support/ordered_set'

module DataMapper
  class DescendantSet
    include Enumerable

    # Initialize a DescendantSet instance
    #
    # @param [#to_ary] descendants
    #   initialize with the descendants
    #
    # @return [undefined]
    #
    # @api private
    def initialize(descendants = [])
      @descendants = OrderedSet.new(descendants)
    end

    # Copy a DescendantSet instance
    #
    # @param [DescendantSet] original
    #   the original descendants
    #
    # @return [undefined]
    #
    # @api private
    def initialize_copy(original)
      @descendants = @descendants.dup
    end

    # Add a descendant
    #
    # @param [Module] descendant
    #
    # @return [DescendantSet]
    #   self
    #
    # @api private
    def <<(descendant)
      @descendants << descendant
      self
    end

    # Remove a descendant
    #
    # Also removes from all descendants
    #
    # @param [Module] descendant
    #
    # @return [DescendantSet]
    #   self
    #
    # @api private
    def delete(descendant)
      @descendants.delete(descendant)
      each { |d| d.descendants.delete(descendant) }
    end

    # Iterate over each descendant
    #
    # @yield [descendant]
    # @yieldparam [Module] descendant
    #
    # @return [DescendantSet]
    #   self
    #
    # @api private
    def each
      @descendants.each do |descendant|
        yield descendant
        descendant.descendants.each { |dd| yield dd }
      end
      self
    end

    # Test if there are any descendants
    #
    # @return [Boolean]
    #
    # @api private
    def empty?
      @descendants.empty?
    end

  end # class DescendantSet
end # module DataMapper
