require 'dm-core/support/ordered_set'

module DataMapper

  # An insertion ordered set of named objects
  #
  # {SubjectSet} uses {DataMapper::OrderedSet}
  # under the hood to keep track of a set of
  # entries. In DataMapper code, a subject
  # can be either a {DataMapper::Property}, or
  # a {DataMapper::Associations::Relationship}.
  #
  # All entries added to instances of this
  # class must respond to the {#name} method
  #
  # The motivation behind this is that we
  # use this class as a base to keep track
  # properties and relationships.
  # The following constraints apply for these
  # types of objects: {Property} names must be
  # unique within any model.
  # {Associations::Relationship} names must be
  # unique within any model
  #
  # When adding an entry with a name that
  # already exists, the already existing
  # entry will be replaced with the new
  # entry with the same name. This is because
  # we want to be able to update properties,
  # and relationship during the course of
  # initializing our application.
  #
  # This also happens to be consistent with
  # the way ruby handles redefining methods,
  # where the last definitions "wins".
  #
  # Furthermore, the builtin ruby {Set#<<} method
  # also updates the old object if a new object
  # gets added.
  #
  # @api private
  class SubjectSet

    # An {OrderedSet::Cache::API} implementation that establishes
    # set semantics based on the name of its entries. The cache
    # uses the entries' names as cache key and refuses to add
    # entries that don't respond_to?(:name).
    #
    # @see OrderedSet::Cache::API
    #
    # @api private
    class NameCache

      include OrderedSet::Cache::API

      # Tests if the given entry qualifies to be added to the cache
      #
      # @param [#name] entry
      #   the entry to be checked
      #
      # @return [Boolean]
      #   true if the entry respond_to?(:name)
      #
      # @api private
      def valid?(entry)
        entry.respond_to?(:name)
      end

      # Given an entry, return the key to be used in the cache
      #
      # @param [#name] entry
      #   the entry to get the key for
      #
      # @return [#to_s, nil]
      #   the entry's name or nil if the entry isn't #valid?
      #
      # @api private
      def key_for(entry)
        valid?(entry) ? entry.name : nil
      end

    end # class NameCache

    include Enumerable

    # The elements in the SubjectSet
    #
    # @return [OrderedSet]
    #
    # @api private
    attr_reader :entries

    # Initialize a SubjectSet
    #
    # @param [Enumerable<#name>] entries
    #   the entries to initialize this set with
    #
    # @api private
    def initialize(entries = [])
      @entries = OrderedSet.new(entries, NameCache)
    end

    # Initialize a copy of a SubjectSet
    #
    # @api private
    def initialize_copy(*)
      @entries = @entries.dup
    end

    # Make sure that entry is part of this SubjectSet
    #
    # If an entry with the same name already exists, it
    # will be updated. If no such named entry exists, it
    # will be added.
    #
    # @param [#name] entry
    #   the entry to be added
    #
    # @return [SubjectSet] self
    #
    # @api private
    def <<(entry)
      entries << entry
      self
    end

    # Delete an entry from this SubjectSet
    #
    # @param [#name] entry
    #   the entry to delete
    #
    # @return [#name, nil]
    #   the deleted entry or nil
    #
    # @api private
    def delete(entry)
      entries.delete(entry)
    end

    # Removes all entries and returns self
    #
    # @return [SubjectSet] self
    #
    # @api private
    def clear
      entries.clear
      self
    end

    # Test if the given entry is included in this SubjectSet
    #
    # @param [#name] entry
    #   the entry to test for
    #
    # @return [Boolean]
    #   true if the entry is included in this SubjectSet
    #
    # @api private
    def include?(entry)
      entries.include?(entry)
    end

    # Tests wether the SubjectSet contains a entry named name
    #
    # @param [#to_s] name
    #   the entry name to test for
    #
    # @return [Boolean]
    #   true if the SubjectSet contains a entry named name
    #
    # @api private
    def named?(name)
      !self[name].nil?
    end

    # Check if there are any entries
    #
    # @return [Boolean]
    #   true if the set contains at least one entry
    #
    # @api private
    def empty?
      entries.empty?
    end

    # Lookup an entry in the SubjectSet based on a given name
    #
    # @param [#to_s] name
    #   the name of the entry
    #
    # @return [Object, nil]
    #   the entry having the given name, or nil if not found
    #
    # @api private
    def [](name)
      name = name.to_s
      entries.detect { |entry| entry.name.to_s == name }
    end

    # Iterate over each entry in the set
    #
    # @yield [entry]
    #   each entry in the set
    #
    # @yieldparam [#name] entry
    #   an entry in the set
    #
    # @return [SubjectSet] self
    #
    # @api private
    def each
      entries.each { |entry| yield(entry) }
      self
    end

    # All entries (or nil values) that have any of the given names
    #
    # @param [Enumerable<#to_s>] names
    #   the names of the desired entries
    #
    # @return [Array<#name, nil>]
    #   an array containing entries whose names match any of the given
    #   names, or nil values for those names with no matching entries
    #   in the set
    #
    # @api private
    def values_at(*names)
      names.map { |name| self[name] }
    end

    # Get the number of elements inside this SubjectSet
    #
    # @return [Integer]
    #   the number of elements
    #
    # @api private
    def size
      entries.size
    end

    # Convert the SubjectSet into an Array
    #
    # @return [Array]
    #   an array containing all the SubjectSet's entries
    #
    # @api private
    def to_ary
      to_a
    end

  end # class SubjectSet
end # module DataMapper
