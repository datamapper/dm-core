module DataMapper
  module Scope
    Model.append_extensions self

    # @api private
    def default_scope(repository_name = nil)
      repository_name = self.default_repository_name if repository_name == :default || repository_name.nil?
      @default_scope ||= {}
      @default_scope[repository_name] ||= {}
    end

    # @api private
    def query
      scope_stack.last
    end

    protected

    # @api semipublic
    def with_scope(query)
      # merge the current scope with the passed in query
      with_exclusive_scope(self.query ? self.query.merge(query) : query) {|*block_args| yield(*block_args) }
    end

    # @api semipublic
    def with_exclusive_scope(query)
      query = DataMapper::Query.new(repository, self, query) if query.kind_of?(Hash)

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
      DataMapper::Query.new(query.repository, query.model, self.default_scope(query.repository.name)).update(query)
    end

    # @api private
    def scope_stack
      scope_stack_for = Thread.current[:dm_scope_stack] ||= {}
      scope_stack_for[self] ||= []
    end
  end # module Scope
end # module DataMapper
