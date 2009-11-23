module DataMapper
  module Model
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
      # @api private
      def default_scope(repository_name = default_repository_name)
        @default_scope ||= {}

        default_repository_name = self.default_repository_name

        @default_scope[repository_name] ||= if repository_name == default_repository_name
          {}
        else
          default_scope(default_repository_name).dup
        end
      end

      # Returns query on top of scope stack
      #
      # @api private
      def query
        Query.new(repository, self, current_scope).freeze
      end

      # @api private
      def current_scope
        scope_stack.last || default_scope(repository.name)
      end

      protected

      # Pushes given query on top of the stack
      #
      # @param [Hash, Query]  Query to add to current scope nesting
      #
      # @api private
      def with_scope(query)
        options = if query.kind_of?(Hash)
          query
        else
          query.options
        end

        # merge the current scope with the passed in query
        with_exclusive_scope(self.query.merge(options)) { |*block_args| yield(*block_args) }
      end

      # Pushes given query on top of scope stack and yields
      # given block, then pops the stack. During block execution
      # queries previously pushed onto the stack
      # have no effect.
      #
      # @api private
      def with_exclusive_scope(query)
        query = if query.kind_of?(Hash)
          Query.new(repository, self, query)
        else
          query.dup
        end

        scope_stack = self.scope_stack
        scope_stack << query.options

        begin
          yield query.freeze
        ensure
          scope_stack.pop
        end
      end

      # Initializes (if necessary) and returns current scope stack
      # @api private
      def scope_stack
        scope_stack_for = Thread.current[:dm_scope_stack] ||= {}
        scope_stack_for[self] ||= []
      end
    end # module Scope

    include Scope
  end # module Model
end # module DataMapper
