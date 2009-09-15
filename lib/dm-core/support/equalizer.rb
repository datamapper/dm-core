module DataMapper
  module Equalizer
    def equalize(*methods)
      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def eql?(other)
          return true if equal?(other)
          instance_of?(other.class) &&
          #{methods.map { |method| "#{method}.eql?(other.#{method})" }.join(' && ')}
        end

        def ==(other)
          return true if equal?(other)
          #{methods.map { |method| "other.respond_to?(#{method.inspect})" }.join(' && ')} &&
          #{methods.map { |method| "#{method} == other.#{method}" }.join(' && ')}
        end

        def hash
          [ #{methods.join(', ')} ].hash
        end
      RUBY
    end
  end
end
