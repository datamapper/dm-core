module Kernel
  BASE_DIR = Dir.getwd
  def __DIR__
    Pathname($1).dirname.expand_path(BASE_DIR) if /\A(.+)?:\d+/ =~ caller[0]
  end
end