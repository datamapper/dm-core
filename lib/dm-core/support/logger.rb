module DataMapper
  class << self #:nodoc:
    attr_accessor :logger
  end

  class Logger < Extlib::Logger
    def initialize(*)
      super
      DataMapper.logger = self
    end
  end # class Logger
end # module DataMapper
