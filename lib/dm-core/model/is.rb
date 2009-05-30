module DataMapper
  module Model
    # Module that provides a common way for plugin authors
    # to implement "is ... " traits (object behaviors that can be shared)
    module Is
      # A common interface to activate plugins for a resource. For instance:
      #
      # class Widget
      #   include DataMapper::Resource
      #
      #   is :list
      # end
      #
      # adds list item behavior to the model. Plugin that wants to conform
      # to "is API" of DataMapper must supply is_+behavior name+ method,
      # for example above it would be is_list.
      #
      # @api public
      def is(plugin, *args, &block)
        generator_method = "is_#{plugin}".to_sym

        if respond_to?(generator_method)
          send(generator_method, *args, &block)
        else
          raise PluginNotFoundError, "could not find plugin named #{plugin}"
        end
      end
    end # module Is

    include Is
  end # module Model
end # module DataMapper
