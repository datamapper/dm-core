module DataMapper
  # The Support module adds functionality to Make Things Easier(tm):
  # * grouping by attributes of objects in an array (returns a hash, see #DataMapper::Support::Enumerable)
  # * adds symbols for operators like <= (lte), like, in, select, etc (see #DataMapper::Support::Symbol)
  # * adds methods for strings, allowing us to ensure strings are wrapped with content (see #DataMapper::Support::String)
  # * pulls in ActiveSupport's Inflector module
  # * loads #DataMapper::Repository and #DataMapper::Base
  module Support
    
    # Extends Array to include an instance method for grouping objects
    module EnumerableExtensions
      
      # Group a collection of elements into groups within a
      # Hash. The value returned by the block passed to group_by
      # is the key, and the value is an Array of items matching
      # that key.
      #
      # === Example
      #   names = %w{ sam scott amy robert betsy }
      #   names.group_by { |name| name.size }
      #   => { 3 => [ "sam", "amy" ], 5 => [ "scott", "betsy" ], 6 => [ "robert" ]}  
      def group_by
        inject(Hash.new { |h,k| h[k] = [] }) do |memo,item|
          memo[yield(item)] << item; memo
        end
      end
  
    end # module EnumerableExtensions
  end # module Support
end # module DataMapper

# Extend Array with DataMapper::Support::EnumerableExtensions
class Array #:nodoc:
  include DataMapper::Support::EnumerableExtensions
end
