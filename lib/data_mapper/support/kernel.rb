module Kernel
  BASE_DIR = Dir.getwd
  def __DIR__
    Pathname($1).dirname.expand_path(BASE_DIR) if /\A(.+)?:\d+/ =~ caller[0]
  end

  # require Repository after adding Kernel::__DIR__
  require __DIR__.parent + 'repository'

  # Delegates to DataMapper::repository.
  # Will not overwrite if a method of the same name is pre-defined.
  def repository(*args, &block)
    DataMapper.repository(*args, &block)
  end
end # module Kernel