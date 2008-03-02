Dir[File.dirname(__FILE__) + "/validatable_extensions/**/*.rb"].each do |path|
  require path
end

#--
# TODO:
#   implement alias_option method for all validations (so we can set :with == :as)
#   make validations orthogonal with allow_nil default to true
#
module DataMapper
  module Validations
      
    def self.included(base) #:nodoc:
      base.class_eval do
        include Validatable
      end
    end
    
  end
end