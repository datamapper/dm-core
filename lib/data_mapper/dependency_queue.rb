module DataMapper
  class DependencyQueue
    
    def initialize
      @dependencies = Hash.new { |h,k| h[k] = [] }
    end
    
    def add(class_name, &b)
      @dependencies[class_name] << b
      resolve!
    end
    
    def resolve!
      @dependencies.each_pair do |class_name, callbacks|
        if Object.const_defined?(class_name)
          klass = Object.const_get(class_name)

          callbacks.each do |b|
            b.call(klass)
          end
          
          callbacks.clear
        end
      end
    end
    
  end # class DependencyQueue
end # module DataMapper