module DataMapper::Spec
  module PendingHelpers
    def pending_if(message, boolean)
      if boolean
        pending(message) { yield }
      else
        yield
      end
    end

    def rescue_if(message, boolean)
      if boolean
        raised = nil
        begin
          yield
          raised = false
        rescue Exception
          raised = true
        end
        raise 'should have raised' if raised == false
      else
        yield
      end
    end
  end
end
