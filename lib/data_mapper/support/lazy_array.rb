class LazyArray  # borrowed partially from StrokeDB

  # these methods should return self or nil
  RETURN_SELF = [ :<<, :clear, :concat, :collect!, :each, :each_index,
    :each_with_index, :insert, :map!, :push, :reject!, :reverse!,
    :reverse_each, :replace, :sort!, :unshift ]

  # these methods should return an instance of this class when an Array
  # would normally be returned
  RETURN_NEW = [ :&, :|, :+, :-, :[], :delete_if, :find_all, :first,
    :grep, :last, :reject, :reverse, :select, :slice, :slice!, :sort,
    :sort_by, :values_at ]

  # these methods should return their results as-is to the caller
  RETURN_PLAIN = [ :[]=, :all?, :any?, :at, :blank?, :collect, :delete,
    :delete_at, :detect, :empty?, :entries, :fetch, :find, :include?,
    :inspect, :index, :inject, :length, :map, :member?, :pop, :rindex,
    :shift, :size, :to_a, :to_ary, :to_s, :to_set, :zip ]

  RETURN_SELF.each do |method|
    class_eval <<-EOS, __FILE__, __LINE__
      def #{method}(*args, &block)
        lazy_load!
        results = @array.#{method}(*args, &block)
        results.kind_of?(Array) ? self : results
      end
    EOS
  end

  RETURN_NEW.each do |method|
    class_eval <<-EOS, __FILE__, __LINE__
      def #{method}(*args, &block)
        lazy_load!
        results = @array.#{method}(*args, &block)
        results.kind_of?(Array) ? wrap(results) : results
      end
    EOS
  end

  RETURN_PLAIN.each do |method|
    class_eval <<-EOS, __FILE__, __LINE__
      def #{method}(*args, &block)
        lazy_load!
        @array.#{method}(*args, &block)
      end
    EOS
  end

  def partition(&block)
    lazy_load!
    true_results, false_results = @array.partition(&block)
    [ wrap(true_results), wrap(false_results) ]
  end

  def eql?(other)
    @array.eql?(other.entries)
  end

  alias == eql?

  def load_with(&block)
    @load_with_proc = block
    self
  end

  def loaded?
    # proc will be nil if the array was loaded
    @load_with_proc.nil?
  end

  def respond_to?(method)
    super || @array.respond_to?(method)
  end

  private

  def initialize(*args, &block)
    @load_with_proc = proc { |v| v }
    @array          = Array.new(*args, &block)
  end

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

  # delegate any not-explicitly-handled methods to @array, if possible.
  # this is handy for handling methods mixed-into Array like group_by
  def method_missing(method, *args, &block)
    if @array.respond_to?(method)
      lazy_load!
      @array.send(method, *args, &block)
    else
      super
    end
  end
end
