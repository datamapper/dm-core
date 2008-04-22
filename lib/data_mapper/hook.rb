module DataMapper
  module Hook
    def self.included(base)
      base.extend(ClassMethods)
    end
    
    module ClassMethods
      #
      # Inject code that executes before the target_method.
      #
      # ==== Parameters
      # target_method<Symbol>:: The name of the class method to inject before
      # method_sym<Symbol>:: The name of the method to run before the target_method
      # block<Block>:: The code to run before the target_method
      #
      # Either method_sym or block is required.
      #
      # -
      # @public
      def before_class_method(target_method, method_sym = nil, &block)
        install_hook :before_class_method, target_method, method_sym, :class, &block
      end

      #
      # Inject code that executes after the target_method.
      #
      # ==== Parameters
      # target_method<Symbol>:: The name of the class method to inject after
      # method_sym<Symbol>:: The name of the method to run after the target_method
      # block<Block>:: The code to run after the target_method
      #
      # Either method_sym or block is required.
      #
      # -
      # @public
      def after_class_method(target_method, method_sym = nil, &block)
        install_hook :after_class_method, target_method, method_sym, :class, &block
      end

      #
      # Inject code that executes before the target_method.
      #
      # ==== Parameters
      # target_method<Symbol>:: The name of the instance method to inject before
      # method_sym<Symbol>:: The name of the method to run before the target_method
      # block<Block>:: The code to run before the target_method
      #
      # Either method_sym or block is required.
      #
      # -
      # @public
      def before(target_method, method_sym = nil, &block)
        install_hook :before, target_method, method_sym, :instance, &block 
      end

      #
      # Inject code that executes after the target_method.
      #
      # ==== Parameters
      # target_method<Symbol>:: The name of the instance method to inject after
      # method_sym<Symbol>:: The name of the method to run after the target_method
      # block<Block>:: The code to run after the target_method
      #
      # Either method_sym or block is required.
      #
      # -
      # @public
      def after(target_method, method_sym = nil, &block)
        install_hook :after, target_method, method_sym, :instance, &block 
      end

      def define_instance_or_class_method(new_meth_name, block, scope)
        if scope == :class
          class << self
            self
          end.instance_eval do
            define_method new_meth_name, block
          end
        elsif scope == :instance
          define_method new_meth_name, block
        else
          raise ArgumentError.new("You need to pass :class or :instance as scope")
        end
      end

      def hooks_with_scope(scope)
        if scope == :class
          class_method_hooks
        elsif scope == :instance
          hooks
        else
          raise ArgumentError.new("You need to pass :class or :instance as scope")
        end
      end
      
      def install_hook(type, name, method_sym, scope, &block)
	raise ArgumentError.new("You need to pass 2 arguments to \"#{type}\".") if ! block_given? and method_sym.nil?
	raise ArgumentError.new("target_method should be a symbol") unless name.is_a?(Symbol)
	raise ArgumentError.new("method_sym should be a symbol") if method_sym && ! method_sym.is_a?(Symbol)
        raise ArgumentError.new("You need to pass :class or :instance as scope") unless [:class, :instance].include?(scope)
                                
        (hooks_with_scope(scope)[name][type] ||= []) << if block
                                                          new_meth_name = "__hooks_#{scope}_#{type}_#{quote_method(name)}_#{hooks_with_scope(scope)[name][type].length}".to_sym
                                                          define_instance_or_class_method(new_meth_name, block, scope)
                                                          new_meth_name
                                                        else
                                                          method_sym
                                                        end
        
        class_eval define_advised_method(name, scope), __FILE__, __LINE__
      end

      def method_with_scope(name, scope)
        if scope == :class
          method(name)
        elsif scope == :instance
          instance_method(name)
        else
          raise ArgumentError.new("You need to pass :class or :instance as scope")
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
          raise ArgumentError.new("You need to pass :class or :instance as scope")
        end

        <<-EOD 
          def #{prefix}#{name}(#{args})
            #{inline_hooks(name, scope, types.first, args)}
            retval = #{inline_call(name, scope, args)}
            #{inline_hooks(name, scope, types.last, args)}
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
          if superclass.method_defined?(name)
            "  super(#{args})\n"
          else
            <<-EOF  
              (@__hooks_#{scope}_#{quote_method(name)}_old_method || @__hooks_#{scope}_#{quote_method(name)}_old_method = 
                self.class.hooks[:#{name}][:old_method].bind(self)).call(#{args})
            EOF
          end
        else
          raise ArgumentError.new("You need to pass :class or :instance as scope")
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
	    # TODO: Test this. Testing order should be before, after and after, before
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
        @hooks ||= Hash.new { |h, k| h[k] = {} }
      end

      def class_method_hooks
        @class_method_hooks ||= Hash.new { |h, k| h[k] = {} }
      end

      def quote_method(name)
	name.to_s.gsub(/\?$/, '_q_').gsub(/!$/, '_b_').gsub(/=$/, '_eq_')
      end
    end
  end # module Hook
end # module DataMapper
