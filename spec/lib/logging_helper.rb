module LoggingHelper
  def logger(adapter = ADAPTER, &block)
    current_adapter = DataObjects.const_get(repository(adapter).adapter.uri.scheme.capitalize)
    old_logger = current_adapter.logger

    log_path = File.join(SPEC_ROOT, "tmp.log")
    handle = File.open(log_path, "a+")
    current_adapter.logger = DataObjects::Logger.new(log_path, 0)
    begin
      yield(handle)
    ensure
      handle.truncate(0)
      handle.close
      current_adapter.logger = old_logger
      File.delete(log_path)
    end
  end
end
