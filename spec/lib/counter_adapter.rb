class CounterAdapter < DataMapper::Adapters::AbstractAdapter
  instance_methods.each { |method| undef_method method unless %w[ __id__ __send__ send class dup object_id kind_of? instance_of? respond_to? equal? assert_kind_of should should_not instance_variable_set instance_variable_get extend ].include?(method.to_s) }

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
