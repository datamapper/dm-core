module Kernel
  private

  ##
  # Delegates to DataMapper.repository().
  #
  # TODO: document this
  # @api public
  def repository(*args, &block)
    DataMapper.repository(*args, &block)
  end
end # module Kernel
