module Kernel

  # Returns the object's singleton class.
  #
  # @return [Class]
  #
  # @api private
  def singleton_class
    class << self
      self
    end
  end unless respond_to?(:singleton_class)  # exists in 1.9.2

private

  # Delegates to DataMapper.repository()
  #
  # @api public
  def repository(*args, &block)
    DataMapper.repository(*args, &block)
  end

end # module Kernel
