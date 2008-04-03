module DataMapper
  module Hook
    def self.included(klass)
      klass.extend(ClassMethods)
    end
    
    module ClassMethods
      def before(target_method, method_sym = nil, &block)
        install_hook :before, "before_#{target_method}".to_sym, target_method, method_sym, &block 
      end
      
      def install_hook(type, name, to_method, method_sym = nil, &block)
        hooks[name] << (block || instance_method(method_sym))

        unless (old_methods[name])
          target = instance_method(to_method)
          old_methods[name] ||= target

          args = args_for(target)
          hook_call = args == "" ? args : ", " << args

          method_def =  "def #{to_method}(#{args})\n"
          method_def << "  run_hook :#{name} #{hook_call}\n" if type == :before
          method_def << "  self.class.old_methods[:#{name}].bind(self).call #{args}\n"
          method_def << "  run_hook :#{name} #{hook_call}\n" if type == :after
          method_def << "end"

          class_eval method_def
        end
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
      
      def old_methods
        @old_methods ||= {}
      end
      
      def hooks
        @hooks ||= Hash.new { |h, k| h[k] = [] }
      end

      def after(target_method, method_sym = nil, &block)
        install_hook :after, "after_#{target_method}".to_sym, target_method, method_sym, &block 
      end
    end

    def run_hook(name, *args)
      self.class.hooks[name].each do |c| 
        case c
          when UnboundMethod
          c.bind(self).call(*args)
          else
          c.call self, *args
        end
      end
    end
  end # module Hook
end # module DataMapper
