module DataMapper
  module Subject
    # Returns a default value of the subject for given resource
    #
    # When default value is a callable object, it is called with resource
    # and subject passed as arguments.
    #
    # @param [Resource] resource
    #   the model instance for which the default is to be set
    #
    # @return [Object]
    #   the default value of this subject for +resource+
    #
    # @api semipublic
    def default_for(resource)
      if @default.respond_to?(:call)
        @default.call(resource, self)
      else
        DataMapper::Ext.try_dup(@default)
      end
    end

    # Returns true if the subject has a default value
    #
    # @return [Boolean]
    #   true if the subject has a default value
    #
    # @api semipublic
    def default?
      @options.key?(:default)
    end
  end
end
