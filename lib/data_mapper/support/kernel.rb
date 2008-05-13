module Kernel
  # Delegates to DataMapper::repository.
  # Will not overwrite if a method of the same name is pre-defined.
  def repository(*args, &block)
    DataMapper.repository(*args, &block)
  end
end # module Kernel
