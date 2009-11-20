module DataMapper
  module Equalizer
    def equalize(*methods)
      define_eql_method(methods)
      define_equivalent_method(methods)
      define_hash_method(methods)
    end

    private

    def define_eql_method(methods)
      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def eql?(other)
          return true if equal?(other)
          instance_of?(other.class) &&
          #{methods.map { |method| "#{method}.eql?(other.#{method})" }.join(' && ')}
        end
      RUBY
    end

    def define_equivalent_method(methods)
      respond_to = []
      equivalent = []

      methods.each do |method|
        respond_to << "other.respond_to?(#{method.inspect})"
        equivalent << "#{method} == other.#{method}"
      end

      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def ==(other)
          return true if equal?(other)
          #{respond_to.join(' && ')} &&
          #{equivalent.join(' && ')}
        end
      RUBY
    end

    def define_hash_method(methods)
      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def hash
          #{methods.map { |method| "#{method}.hash" }.join(' ^ ')}
        end
      RUBY
    end
  end
end
