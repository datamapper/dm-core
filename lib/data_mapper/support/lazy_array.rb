class LazyArray  # borrowed partially from StrokeDB
  instance_methods.each { |m| undef_method m unless %w[ __id__ __send__ class clone dup equal? kind_of? instance_of? is_a? inspect object_id respond_to? should should_not ].include?(m) }

  # when these methods return an Array, it will be wrapped in an
  # instance of the current class using the wrap() method
  RETURN_WRAPPED = [ :first, :last, :reject, :reverse, :select, :slice,
    :slice!, :sort, :values_at ]

  # when these methods return an Array, it will return self, otherwise
  # the result will be passed as-is to the caller
  RETURN_SELF = [ :clear, :concat, :collect!, :each, :each_index,
    :insert, :push, :reject!, :reverse!, :reverse_each, :replace,
    :sort!, :unshift ]

  def initialize(*args, &block)
    @load_with_proc = proc { |v| v }
    @array          = Array.new(*args, &block)
  end

  def load_with(&block)
    @load_with_proc = block
    self
  end

  def loaded?
    # proc will be nil if the array was loaded
    @load_with_proc.nil?
  end

  def eql?(other)
    return true if equal?(other)
    entries == other.entries
  end

  alias == eql?

  def respond_to?(method)
    return true if super
    @array.respond_to?(method)
  end

  RETURN_SELF.each do |method|
    class_eval <<-EOS, __FILE__, __LINE__
      def #{method}(*args, &block)
        lazy_load!
        results = @array.#{method}(*args, &block)
        results.kind_of?(Array) ? self : results
      end
    EOS
  end

  RETURN_WRAPPED.each do |method|
    class_eval <<-EOS, __FILE__, __LINE__
      def #{method}(*args, &block)
        lazy_load!
        results = @array.#{method}(*args, &block)
        results.kind_of?(Array) ? wrap(results) : results
      end
    EOS
  end

  private

  def initialize_copy(original)
    @array = original.entries
    @load_with_proc = nil if @array.any?
  end

  def lazy_load!
    if proc = @load_with_proc
      @load_with_proc = nil
      proc[self]
    end
  end

  # subclasses may override this to wrap the results in an
  # instance of their class
  def wrap(results)
    self.class.new(results)
  end

  # delegate to @array and return the results to the caller
  def method_missing(method, *args, &block)
    if @array.respond_to?(method)
      lazy_load!
      @array.__send__(method, *args, &block)
    else
      super
    end
  end
end
