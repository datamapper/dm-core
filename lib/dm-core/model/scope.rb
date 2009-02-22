module DataMapper
  module Scope
    Model.append_extensions self

    # TODO: document
    # @api private
    def default_scope(repository_name = default_repository_name)
      @default_scope ||= {}
      @default_scope[repository_name] ||= {}
    end

    # TODO: document
    # @api private
    def query
      scope_stack.last
    end

    protected

    # TODO: document
    # @api semipublic
    def with_scope(query)
      # merge the current scope with the passed in query
      with_exclusive_scope(self.query ? self.query.merge(query) : query) { |*block_args| yield(*block_args) }
    end

    # TODO: document
    # @api semipublic
    def with_exclusive_scope(query)
      query = Query.new(repository, self, query) if query.kind_of?(Hash)

      scope_stack << query

      begin
        return yield(query)
      ensure
        scope_stack.pop
      end
    end

    private

    # TODO: document
    # @api private
    def merge_with_default_scope(query)
      repository = query.repository

      Query.new(repository, self, default_scope_for_repository(repository.name)).update(query)
    end

    # TODO: document
    # @api private
    def scope_stack
      scope_stack_for = Thread.current[:dm_scope_stack] ||= {}
      scope_stack_for[self] ||= []
    end

    # TODO: document
    # @api private
    def default_scope_for_repository(repository_name)
      if repository_name == default_repository_name
        default_scope.dup
      else
        default_scope.merge(default_scope(repository_name))
      end
    end
  end # module Scope
end # module DataMapper
