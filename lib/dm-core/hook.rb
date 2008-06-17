module DataMapper
  module Hook
    include Assertions

    # Inject code that executes before the target class method.
    #
    # @param target_method<Symbol>  the name of the class method to inject before
    # @param method_sym<Symbol>     the name of the method to run before the
    #   target_method
    # @param block<Block>           the code to run before the target_method
    #
    # @note
    #   Either method_sym or block is required.
    # -
    # @api public
    def before_class_method(target_method, method_sym = nil, &block)
      install_hook :before_class_method, target_method, method_sym, :class, &block
    end

    #
    # Inject code that executes after the target class method.
    #
    # @param target_method<Symbol>  the name of the class method to inject after
    # @param method_sym<Symbol>     the name of the method to run after the target_method
    # @param block<Block>           the code to run after the target_method
    #
    # @note
    #   Either method_sym or block is required.
    # -
    # @api public
    def after_class_method(target_method, method_sym = nil, &block)
      install_hook :after_class_method, target_method, method_sym, :class, &block
    end

    #
    # Inject code that executes before the target instance method.
    #
    # @param target_method<Symbol>  the name of the instance method to inject before
    # @param method_sym<Symbol>     the name of the method to run before the
    #   target_method
    # @param block<Block>           the code to run before the target_method
    #
    # @note
    #   Either method_sym or block is required.
    # -
    # @api public
    def before(target_method, method_sym = nil, &block)
      install_hook :before, target_method, method_sym, :instance, &block
    end

    #
    # Inject code that executes after the target instance method.
    #
    # @param target_method<Symbol>  the name of the instance method to inject after
    # @param method_sym<Symbol>     the name of the method to run after the
    #   target_method
    # @param block<Block>           the code to run after the target_method
    #
    # @note
    #   Either method_sym or block is required.
    # -
    # @api public
    def after(target_method, method_sym = nil, &block)
      install_hook :after, target_method, method_sym, :instance, &block
    end

    def define_instance_or_class_method(new_meth_name, block, scope)
      case scope
        when :class
          class << self
            self
          end.instance_eval do
            define_method new_meth_name, block
          end
        when :instance
          define_method new_meth_name, block
        else
          raise ArgumentError, 'You need to pass :class or :instance as scope'
      end
    end

    def hooks_with_scope(scope)
      case scope
        when :class    then class_method_hooks
        when :instance then hooks
        else
          raise ArgumentError, 'You need to pass :class or :instance as scope'
      end
    end

    def install_hook(type, name, method_sym, scope, &block)
      assert_kind_of 'name',       name,       Symbol
      assert_kind_of 'method_sym', method_sym, Symbol unless method_sym.nil?
      assert_kind_of 'scope',      scope,      Symbol

      if !block_given? and method_sym.nil?
        raise ArgumentError, "You need to pass 2 arguments to \"#{type}\"."
      end

      unless [ :class, :instance ].include?(scope)
        raise ArgumentError, 'You need to pass :class or :instance as scope'
      end

      hooks_with_scope(scope)[name][type] ||= []

      hooks_with_scope(scope)[name][type] << if block
        new_meth_name = "__hooks_#{scope}_#{type}_#{quote_method(name)}_#{hooks_with_scope(scope)[name][type].length}".to_sym
        define_instance_or_class_method(new_meth_name, block, scope)
        new_meth_name
      else
        method_sym
      end

      if scope == :instance && !instance_methods(false).include?(name.to_s)
        advised_method = define_advised_method(name, scope)
        advised_method_module = Module.new do
          class_eval advised_method, __FILE__, __LINE__
        end
        class_eval { include advised_method_module }
      else
        class_eval define_advised_method(name, scope), __FILE__, __LINE__
      end
    end

    def method_with_scope(name, scope)
      case scope
        when :class    then method(name)
        when :instance then instance_method(name)
        else
          raise ArgumentError, 'You need to pass :class or :instance as scope'
      end
    end

    # FIXME Return the method value
    def define_advised_method(name, scope)
      args = args_for(hooks_with_scope(scope)[name][:old_method] ||= method_with_scope(name, scope))

      prefix = ""
      types = [:before, :after]
      if scope == :class
        prefix = "self."
        types = [:before_class_method, :after_class_method]
      elsif scope != :instance
        raise ArgumentError, 'You need to pass :class or :instance as scope'
      end

      <<-EOD
        def #{prefix}#{name}(#{args})
          retval = nil
          catch(:halt) do
            #{inline_hooks(name, scope, types.first, args)}
            retval = #{inline_call(name, scope, args)}
          end

          catch(:halt) do
            #{inline_hooks(name, scope, types.last, args)}
          end
          retval
        end
      EOD
    end

    def inline_call(name, scope, args)
      if scope == :class
        if (class << superclass; self; end.method_defined?(name))
          "  super(#{args})\n"
        else
          <<-EOF
            (@__hooks_#{scope}_#{quote_method(name)}_old_method || @__hooks_#{scope}_#{quote_method(name)}_old_method =
            self.class_method_hooks[:#{name}][:old_method]).call(#{args})
          EOF
        end
      elsif scope == :instance
        unless instance_methods(false).include?(name.to_s)
          "  super(#{args})\n"
        else
          <<-EOF
            (@__hooks_#{scope}_#{quote_method(name)}_old_method || @__hooks_#{scope}_#{quote_method(name)}_old_method =
            self.class.hooks[:#{name}][:old_method].bind(self)).call(#{args})
          EOF
        end
      else
        raise ArgumentError, 'You need to pass :class or :instance as scope'
      end
    end

    def inline_hooks(name, scope, type, args)
      return '' unless hooks_with_scope(scope)[name][type]

      method_def = ""
      hooks_with_scope(scope)[name][type].each_with_index do |e, i|
        case e
          when Symbol
            method_def << "  #{e}(#{args})\n"
          else
            # TODO: Test this. Testing order should be before, after and after,
            # before
            method_def << "(@__hooks_#{scope}_#{quote_method(name)}_#{type}_#{i} || "
            method_def << "  @__hooks_#{scope}_#{quote_method(name)}_#{type}_#{i} = self.class.hooks_with_scope(#{scope.inspect})[:#{name}][:#{type}][#{i}])"
            method_def << ".call #{args}\n"
        end
      end

      method_def
    end

    def args_for(method)
      if method.arity == 0
        ""
      elsif method.arity > 0
        "_" << (1 .. method.arity).to_a.join(", _")
      elsif (method.arity + 1) < 0
        "_" << (1 .. (method.arity).abs - 1).to_a.join(", _") << ", *args"
      else
        "*args"
      end
    end

    def hooks
      @hooks ||= if self.superclass.respond_to?(:hooks)
        self.superclass.hooks
      else
        Hash.new { |h, k| h[k] = {} }
      end
    end

    def class_method_hooks
      @class_method_hooks ||= if self.superclass.respond_to?(:class_method_hooks)
        self.superclass.class_method_hooks
      else
        Hash.new { |h, k| h[k] = {} }
      end
    end

    def quote_method(name)
      name.to_s.gsub(/\?$/, '_q_').gsub(/!$/, '_b_').gsub(/=$/, '_eq_')
    end
  end # module Hook


  DataMapper::Resource::ClassMethods.append_extensions Hook
end # module DataMapper
