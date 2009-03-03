module DataMapper
  # Module with query scoping functionality.
  #
  # Scopes are implemented using simple array based
  # stack that is thread local. Default scope can be set
  # on a per repository basis.
  #
  # Scopes are merged as new queries are nested.
  # It is also possible to get exclusive scope access
  # using +with_exclusive_scope+
  module Scope
    Model.append_extensions self

    # TODO: document
    # @api private
    def default_scope(repository_name = default_repository_name)
      @default_scope ||= {}
      @default_scope[repository_name] ||= {}
    end

    # Returns query on top of scope stack
    # @api private
    def query
      scope_stack.last
    end

    protected

    # If stack is not empty, merges query with one on top of the stack
    # and pushes resulting combined query onto the stack
    #
    # otherwise just pushes given query on top of the stack
    #
    # @param [Hash, Query]  Query to add to current scope nesting
    #
    # @api semipublic
    def with_scope(query)
      # merge the current scope with the passed in query
      with_exclusive_scope(self.query ? self.query.merge(query) : query) { |*block_args| yield(*block_args) }
    end

    # Pushes given query on top of scope stack and yields
    # given block, then pops the stack. During block execution
    # queries previously pushed onto the stack
    # have no effect.
    #
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

    # Merges query with a default query for repository this
    # query works in
    #
    # @api private
    def merge_with_default_scope(query)
      repository = query.repository

      Query.new(repository, self, default_scope_for_repository(repository.name)).update(query)
    end

    # Initializes (if necessary) and returns current scope stack
    # @api private
    def scope_stack
      scope_stack_for = Thread.current[:dm_scope_stack] ||= {}
      scope_stack_for[self] ||= []
    end

    # Returns current scope for given repository,
    # or globally default scope for default repository
    #
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
