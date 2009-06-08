module DataMapper
  module Deprecate
    def deprecate(old_method, new_method)
      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{old_method}(*args, &block)
          warn "\#{self.class}##{old_method} is deprecated, use \#{self.class}##{new_method} instead (\#{caller[0]})"
          send(#{new_method.inspect}, *args, &block)
        end
      RUBY
    end
  end # module Deprecate
end # module DataMapper
