module DataMapper
  module Scope
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      protected

      def with_scope(query, &block)
        # merge the current scope with the passed in query
        with_exclusive_scope(current_scope ? current_scope.merge(query) : query, &block)
      end

      def with_exclusive_scope(query, &block)
        query = DataMapper::Query.new(self, query) if Hash === query

        scope_stack << query

        begin
          yield
        ensure
          scope_stack.pop
        end
      end

      private

      def scope_stack
        scope_stack_for = Thread.current[:dm_scope_stack] ||= Hash.new { |h,k| h[k] = [] }
        scope_stack_for[self]
      end

      def current_scope
        scope_stack.last
      end
    end # module ClassMethods
  end # module Scope
end # module DataMapper
