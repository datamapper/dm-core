module DataMapper
  module Scope
    Model.append_extensions self

    # @api private
    def default_scope
      @default_scope ||= {}
    end

    # @api private
    def query
      scope_stack.last
    end

    protected

    # @api semipublic
    def with_scope(query, &block)
      # merge the current scope with the passed in query
      with_exclusive_scope(self.query ? self.query.merge(query) : query, &block)
    end

    # @api semipublic
    def with_exclusive_scope(query, &block)
      query = DataMapper::Query.new(repository, self, query) if query.kind_of?(Hash)

      # merge the query with the default scope if the scope stack is empty
      if scope_stack.empty?
        query = merge_with_default_scope(query)
      end

      scope_stack << query

      begin
        return yield(query)
      ensure
        scope_stack.pop
      end
    end

    private

    # @api private
    def merge_with_default_scope(query)
      DataMapper::Query.new(query.repository, query.model, default_scope).update(query)
    end

    # @api private
    def scope_stack
      scope_stack_for = Thread.current[:dm_scope_stack] ||= Hash.new { |h,model| h[model] = [] }
      scope_stack_for[self]
    end
  end # module Scope
end # module DataMapper
