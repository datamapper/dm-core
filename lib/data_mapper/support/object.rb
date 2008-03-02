module DataMapper
  module Support
    module Object
      
      def self.included(base)
        
        nested_constants = Hash.new do |h,k|
          klass = Object
          k.split('::').each do |c|
            klass = klass.const_get(c)
          end
          h[k] = klass
        end
        
        base.instance_variable_set("@nested_constants", nested_constants)
        base.send(:include, ClassMethods)
      end
      
      module ClassMethods
        def recursive_const_get(nested_name)
          @nested_constants[nested_name]
        end
      end
    end
  end
end

class Object #:nodoc:
  include DataMapper::Support::Object
end

# require 'benchmark'
# 
# N = 1_000_000
# 
# puts Benchmark.measure {
#   N.times { Object.recursive_const_get('DataMapper::Support::Object') }
# }
# 
# puts Benchmark.measure {
#   N.times {
#     klass = Object
#     'DataMapper::Support::Object'.split('::').each do |c|
#       klass = klass.const_get(c)
#     end
#     klass  
#   }
# }
# 
# __END__
# >>> object.rb
# 
#   0.910000   0.000000   0.910000 (  0.916914)
#   6.140000   0.010000   6.150000 (  6.151984)