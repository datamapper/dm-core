module DataMapper
  module Scope
    def query
      scope_stack.last
    end

    protected

    def with_scope(query, &block)
      # merge the current scope with the passed in query
      with_exclusive_scope(self.query ? self.query.merge(query) : query, &block)
    end

    def with_exclusive_scope(query, &block)
      query = DataMapper::Query.new(repository, self, query) if query.kind_of?(Hash)

      scope_stack << query

      begin
        return yield(query)
      ensure
        scope_stack.pop
      end
    end

    private

    def scope_stack
      scope_stack_for = Thread.current[:dm_scope_stack] ||= Hash.new { |h,k| h[k] = [] }
      scope_stack_for[self]
    end

    Model.send(:include, self)
  end # module Scope
end # module DataMapper
