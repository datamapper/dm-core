module DataMapper
  ##
  #
  # DataMapper's DependencyQueue is used to store callbacks for classes which
  # may or may not be loaded already.
  #
  class DependencyQueue
    def initialize
      @dependencies = Hash.new { |h,k| h[k] = [] }
    end

    def add(class_name, &callback)
      @dependencies[class_name] << callback
      resolve!
    end

    def resolve!
      @dependencies.each do |class_name, callbacks|
        next unless Object.const_defined?(class_name)
        klass = Object.const_get(class_name)
        callbacks.each do |callback|
          callback.call(klass)
        end
        callbacks.clear
      end
    end

  end # class DependencyQueue
end # module DataMapper
