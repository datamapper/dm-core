module DataMapper

  # An ordered set of things
  #
  # {OrderedSet} implements set behavior and keeps
  # track of the order in which entries were added.
  #
  # {OrderedSet} allows to inject a class that implements
  # {OrderedSet::Cache::API} at construction time, and will
  # use that cache implementation to enforce set semantics
  # and perform internal caching of insertion order.
  #
  # @see OrderedSet::Cache::API
  # @see OrderedSet::Cache
  # @see SubjectSet::NameCache
  #
  # @api private
  class OrderedSet

    # The default cache used by {OrderedSet}
    #
    # Uses a {Hash} as internal storage and enforces set semantics
    # by calling #eql? and #hash on the set's entries.
    #
    # @api private
    class Cache

      # The default implementation of the {API} that {OrderedSet} expects from
      # the cache object that it uses to
      #
      #     1. keep track of insertion order
      #     2. enforce set semantics.
      #
      # Classes including {API} must customize the behavior of the cache in 2 ways:
      #
      # They must determine the value to use as cache key and thus set discriminator,
      # by implementing the {#key_for} method. The {#key_for} method accepts an arbitrary
      # object as param and the method is free to return whatever value from that method.
      # Obviously this will most likely be some attribute or value otherwise derived from
      # the object that got passed in.
      #
      # They must determine which objects are valid set entries by overwriting the
      # {#valid?} method. The {#valid?} method accepts an arbitrary object as param and
      # the overwriting method must return either true or false.
      #
      # The motivation behind this is that set semantics cannot always be enforced
      # by calling {#eql?} and {#hash} on the set's entries. For example, two entries
      # might be considered unique wrt the set if their names are the same, but other
      # internal state differs. This is exactly the case for {DataMapper::Property} and
      # {DataMapper::Associations::Relationship} objects.
      #
      # @see DataMapper::SubjectSet::NameCache
      #
      # @api private
      module API

        # Initialize a new Cache
        #
        # @api private
        def initialize
          @cache = {}
        end

        # Tests if the given entry qualifies to be added to the cache
        #
        # @param [Object] entry
        #   the entry to be checked
        #
        # @return [Boolean]
        #   true if the entry qualifies to be added to the cache
        #
        # @api private
        def valid?(entry)
          raise NotImplementedError, "#{self}#valid? must be implemented"
        end

        # Given an entry, return the key to be used in the cache
        #
        # @param [Object] entry
        #   the entry to get the key for
        #
        # @return [Object, nil]
        #   a value derived from the entry that is used as key in the cache
        #
        # @api private
        def key_for(entry)
          raise NotImplementedError, "#{self}#key_for must be implemented"
        end

        # Check if the entry exists in the cache
        #
        # @param [Object] entry
        #   the entry to test for
        #
        # @return [Boolean]
        #   true if entry is included in the cache
        #
        # @api private
        def include?(entry)
          @cache.has_key?(key_for(entry))
        end

        # Return the index for the entry in the cache
        #
        # @param [Object] entry
        #   the entry to get the index for
        #
        # @return [Integer, nil]
        #   the index for the entry, or nil if it does not exist
        #
        # @api private
        def [](entry)
          @cache[key_for(entry)]
        end

        # Set the index for the entry in the cache
        #
        # @param [Object] entry
        #   the entry to set the index for
        # @param [Integer] index
        #   the index to assign to the given entry
        #
        # @return [Integer]
        #   the given index for the entry
        #
        # @api private
        def []=(entry, index)
          if valid?(entry)
            @cache[key_for(entry)] = index
          end
        end

        # Delete an entry from the cache
        #
        # @param [Object] entry
        #   the entry to delete from the cache
        #
        # @return [API] self
        #
        # @api private
        def delete(entry)
          deleted_index = @cache.delete(key_for(entry))
          if deleted_index
            @cache.each do |key, index|
              @cache[key] -= 1 if index > deleted_index
            end
          end
          deleted_index
        end

        # Removes all entries and returns self
        #
        # @return [API] self
        #
        # @api private
        def clear
          @cache.clear
          self
        end

      end # module API

      include API

      # Tests if the given entry qualifies to be added to the cache
      #
      # @param [Object] entry
      #   the entry to be checked
      #
      # @return [true] true
      #
      # @api private
      def valid?(entry)
        true
      end

      # Given an entry, return the key to be used in the cache
      #
      # @param [Object] entry
      #   the entry to get the key for
      #
      # @return [Object]
      #   the passed in entry
      #
      # @api private
      def key_for(entry)
        entry
      end

    end # class Cache

    include Enumerable
    extend  Equalizer

    # This set's entries
    #
    # The order in this Array is not guaranteed
    # to be the order in which the entries were
    # inserted. Use #each to access the entries
    # in insertion order.
    #
    # @return [Array]
    #  this set's entries
    #
    # @api private
    attr_reader :entries

    equalize :entries

    # Initialize an OrderedSet
    #
    # @param [#each] entries
    #   the entries to initialize this set with
    # @param [Class<Cache::API>] cache
    #   the cache implementation to use
    #
    # @api private
    def initialize(entries = [], cache = Cache)
      @cache   = cache.new
      @entries = []
      merge(entries.to_ary)
    end

    # Initialize a copy of OrderedSet
    #
    # @api private
    def initialize_copy(*)
      @cache   = @cache.dup
      @entries = @entries.dup
    end

    # Get the entry at the given index
    #
    # @param [Integer] index
    #   the index of the desired entry
    #
    # @return [Object, nil]
    #   the entry at the given index, or nil if no entry is present
    #
    # @api private
    def [](index)
      entries[index]
    end

    # Add or update an entry in the set
    #
    # If the entry to add isn't part of the set already,
    # it will be added. If an entry with the same cache
    # key as the entry to add is part of the set already,
    # it will be replaced with the given entry.
    #
    # @param [Object] entry
    #   the entry to be added
    #
    # @return [OrderedSet] self
    #
    # @api private
    def <<(entry)
      if index = @cache[entry]
        entries[index] = entry
      else
        @cache[entry] = size
        entries << entry
      end
      self
    end

    # Merge with another Enumerable object
    #
    # @param [#each] other
    #   the Enumerable to merge with this OrderedSet
    #
    # @return [OrderedSet] self
    #
    # @api private
    def merge(other)
      other.each { |entry| self << entry }
      self
    end

    # Delete an entry from this OrderedSet
    #
    # @param [Object] entry
    #   the entry to delete
    #
    # @return [Object, nil]
    #   the deleted entry or nil
    #
    # @api private
    def delete(entry)
      if index = @cache.delete(entry)
        entries.delete_at(index)
      end
    end

    # Removes all entries and returns self
    #
    # @return [OrderedSet] self
    #
    # @api private
    def clear
      @cache.clear
      entries.clear
      self
    end

    # Iterate over each entry in the set
    #
    # @yield [entry]
    #   all entries in the set
    #
    # @yieldparam [Object] entry
    #   an entry in the set
    #
    # @return [OrderedSet] self
    #
    # @api private
    def each
      return to_enum unless block_given?
      entries.each { |entry| yield(entry) }
      self
    end

    # The number of entries
    #
    # @return [Integer]
    #   the number of entries
    #
    # @api private
    def size
      entries.size
    end

    # Check if there are any entries
    #
    # @return [Boolean]
    #   true if the set is empty
    #
    # @api private
    def empty?
      entries.empty?
    end

    # Check if the entry exists in the set
    #
    # @param [Object] entry
    #   the entry to test for
    #
    # @return [Boolean]
    #   true if entry is included in the set
    #
    # @api private
    def include?(entry)
      entries.include?(entry)
    end

    # Return the index for the entry in the set
    #
    # @param [Object] entry
    #   the entry to check the set for
    #
    # @return [Integer, nil]
    #   the index for the entry, or nil if it does not exist
    #
    # @api private
    def index(entry)
      @cache[entry]
    end

    # Convert the OrderedSet into an Array
    #
    # @return [Array]
    #   an array containing all the OrderedSet's entries
    #
    # @api private
    def to_ary
      entries
    end

  end # class OrderedSet
end # module DataMapper
