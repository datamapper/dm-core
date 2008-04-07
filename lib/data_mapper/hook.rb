module DataMapper
  module Hook
    def self.included(klass)
      klass.extend(ClassMethods)
    end
    
    module ClassMethods
      def before(target_method, method_sym = nil, &block)
        install_hook :before, target_method, method_sym, &block 
      end
      
      def install_hook(type, name, method_sym = nil, &block)
        (hooks[name][type] ||= []) << if block
          new_meth_name = "__hooks_#{type}_#{name}_#{hooks[name][type].length}".to_sym
          define_method new_meth_name, block
          new_meth_name
        else
          method_sym
        end
        
        class_eval define_advised_method(name), __FILE__, __LINE__
      end
      
      def define_advised_method(name)
        args = args_for(hooks[name][:old_method] ||= instance_method(name))

        <<-EOD 
          def #{name}(#{args})
            #{inline_hooks(name, :before, args)}
            #{inline_call(name, args)}
            #{inline_hooks(name, :after, args)}
          end
        EOD
      end
      
      def inline_call(name, args)
        if self.superclass.method_defined?(name)
          "  super(#{args})\n"
        else
          <<-EOF  
            (@__hooks_#{name}_old_method || @__hooks_#{name}_old_method = 
              self.class.hooks[:#{name}][:old_method].bind(self)).call(#{args})
          EOF
        end
      end
      
      def inline_hooks(name, type, args)
        return '' unless hooks[name][type]
        
        method_def = ""
        hooks[name][type].each_with_index do |e, i|
          case e
          when Symbol
            method_def << "  #{e}(#{args})\n"
          else
            method_def << "(@__hooks_#{name}_#{i} || "
            method_def << "  @__hooks_#{name}_#{i} = self.class.hooks[:#{name}][:#{type}][#{i}])"
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

      def after(target_method, method_sym = nil, &block)
        install_hook :after, target_method, method_sym, &block 
      end
    end
  end # module Hook
end # module DataMapper
