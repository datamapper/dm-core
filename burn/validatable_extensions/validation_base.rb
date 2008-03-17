module Validatable
  class ValidationBase
    alias_method :old_init, :initialize
  
    DEFAULT_EVENTS = [:validate, :create, :save, :update]

    def initialize(klass, attribute, options={})
      events = [options.delete(:on)].flatten.compact + [options.delete(:event)].flatten.compact
      raise ArgumentError.new("Events must be one of #{DEFAULT_EVENTS.inspect}") unless (events & DEFAULT_EVENTS).size == events.size
      options[:groups] ||= events unless events.empty? ### <- Danger will robinson
      old_init(klass, attribute, options)
    end
  
    def humanized_attribute
      @humanized_attribute ||= Inflector.humanize(self.attribute.to_s)
    end
  end
end