module DataMapper
  
  # CallbacksHelper adds a class-method ClassMethods#callbacks
  # when included in a class, and defines short-cut class-methods to
  # add delegates to callbacks for the built-in Callbacks::EVENTS.
  module CallbacksHelper
    
    # The ::included callback extends the included class with a
    # ::callbacks method, and sets up helper methods for the standard
    # events declared in Callbacks::EVENTS.
    def self.included(base)
      base.extend(ClassMethods)
      
      # Declare helpers for the standard EVENTS
      Callbacks::EVENTS.each do |name|
        base.class_eval <<-EOS
          def self.#{name}(string = nil, &block)
            if string.nil?
              callbacks.add(:#{name}, block)
            else
              callbacks.add(:#{name}, string)
            end
          end
        EOS
      end
    end
    
    # Defines class-methods for the class that CallbacksHelper is
    # included in.
    module ClassMethods
      
      # Provides lazily initialized access to a Callbacks instance.
      def callbacks
        @callbacks || ( @callbacks = DataMapper::Callbacks.new )
      end
    end
  end
  
  # Callbacks is a collection to assign and execute blocks of code when
  # hooks throughout the DataMapper call Callbacks#execute. A set of the
  # standard callbacks is declared in the Callbacks::EVENTS array.
  class Callbacks
  
    # These are a collection of default callbacks that are hooked
    # into the DataMapper. You're free to add your own events just by
    # calling #add, but you'll have add the appropriate hooks into the
    # system to actually execute them yourself.
    EVENTS = [
      :before_materialize, :after_materialize,
      :before_save, :after_save,
      :before_create, :after_create,
      :before_update, :after_update,
      :before_destroy, :after_destroy,
      :before_validation, :after_validation
      ]
    
    # Initializes an internal Hash that ensures callback names are always
    # of type Symbol, and assigns an Array to store your delegating code
    # when the callback is looked-up by name.
    def initialize
      @callbacks = Hash.new do |h,k|
        raise 'Callback names must be Symbols' unless k.kind_of?(Symbol)
        h[k] = Set.new
      end
    end
    
    # Executes a given callback and returns TRUE or FALSE depending on the
    # return value of the callbacks. All callbacks must return successfully
    # in order for the call to #execute to return TRUE. Callbacks always
    # execute against an +instance+. You may pass  additional arguments
    # which will in turn be passed to any Proc objects assigned to a specific
    # callback. Strings assigned to callbacks do not accept parameters.
    # They are instance-eval'ed instead. When the callback is a Symbol,
    # it is sent to the instance under the assumption it is a method call.
    def execute(name, instance, *args)
      @callbacks[name].all? do |callback|
        case callback
        when String then instance.instance_eval(callback)
        when Proc then callback[instance, *args]
        when Symbol then instance.send(callback, *args)
        else raise ''
        end
      end
    end
    
    # Asign delegating code to a callback. The +block+ parameter
    # can be a Proc object, a String which will be eval'ed when
    # the callback is executed, or a Symbol, which will be sent to
    # the instance executed against (as a method call).
    def add(name, block)
      callback = @callbacks[name]
      raise ArgumentError.new("You didn't specify a callback in String, Symbol or Proc form.") unless [String, Proc, Symbol].detect { |type| block.is_a?(type) }
      callback << block
    end

    def dup
      copy = self.class.new
      @callbacks.each_pair do |name, callbacks|
        callbacks.each do |callback|
          copy.add(name, callback)
        end
      end
      return copy
    end
  end
  
end