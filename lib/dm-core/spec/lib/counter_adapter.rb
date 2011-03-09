class CounterAdapter < DataMapper::Adapters::AbstractAdapter
  instance_methods.each do |method|
    next if method =~ /\A__/ ||
      %w[ send class dup object_id kind_of? instance_of? respond_to? equal? freeze frozen? should should_not instance_variables instance_variable_set instance_variable_get instance_variable_defined? remove_instance_variable extend inspect copy_object ].include?(method.to_s)
    undef_method method
  end

  attr_reader :counts

  def kind_of?(klass)
    super || @adapter.kind_of?(klass)
  end

  def instance_of?(klass)
    super || @adapter.instance_of?(klass)
  end

  def respond_to?(method, include_private = false)
    super || @adapter.respond_to?(method, include_private)
  end

  private

  def initialize(adapter)
    @counts  = Hash.new { |hash, key| hash[key] = 0 }
    @adapter = adapter
    @count   = 0
  end

  def increment_count_for(method)
    @counts[method] += 1
  end

  def method_missing(method, *args, &block)
    increment_count_for(method)
    @adapter.send(method, *args, &block)
  end
end
