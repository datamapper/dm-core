class Object
  @nested_constants = Hash.new do |h,k|
    klass = Object
    k.split('::').each do |c|
      klass = klass.const_get(c)
    end
    h[k] = klass
  end

  def self.recursive_const_get(nested_name)
    @nested_constants[nested_name]
  end

  unless instance_methods.include?('instance_variable_defined?')
    def instance_variable_defined?(method)
      instance_variables.include?(method.to_s)
    end
  end
end # class Object
