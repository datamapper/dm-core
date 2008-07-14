module DataMapper
  module Scope
    Model.append_extensions self

    # @api private
    def default_scope(repo = nil)
      repo = self.default_repository_name if repo == :default || repo.nil?
      @default_scope ||= Hash.new{|h,k| h[k] = {}}
      @default_scope[repo]
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
      DataMapper::Query.new(query.repository, query.model, default_scope_for_query(query)).update(query)
    end

    # @api private
    def scope_stack
      scope_stack_for = Thread.current[:dm_scope_stack] ||= Hash.new { |h,model| h[model] = [] }
      scope_stack_for[self]
    end
    
    # @api private
    def default_scope_for_query(query)
      name = query.repository.name      
      default_name = query.model.default_repository_name
      self.default_scope(default_name).merge(self.default_scope(name))
    end
  end # module Scope
end # module DataMapper
