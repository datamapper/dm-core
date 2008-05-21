class Object
  unless instance_methods.include?('instance_variable_defined?')
    def instance_variable_defined?(method)
      instance_variables.include?(method.to_s)
    end
  end

  def find_const(nested_name)
    NESTED_CONSTANTS[nested_name]
  end

  private
  NESTED_CONSTANTS = Hash.new do |h,k|
    klass = Object
    k.split('::').each do |c|
      klass = klass.const_get(c) unless c.empty?
    end
    h[k] = klass
  end

end # class Object
