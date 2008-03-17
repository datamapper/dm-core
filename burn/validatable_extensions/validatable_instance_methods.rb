# = Validations
# DataMapper uses the 'Validatable' gem to validate models.
# 
# Example:
#   class Person < DataMapper::Base
#     property :name, :string
#     property :email, :string
#     property :password, :string
#
#     validates_presence_of :name, :email
#     validates_length_of :password, :minimum => 6, :on => :create
#     validates_format_of :email, :with => :email_address, :message => 'Please provide a valid email address.'
#   end
#
#   p = Person.new
#   p.valid? #=> false
#   p.errors.full_messages #=> ["Email must not be blank", "Please provide a valid email address.", "Name must not be blank"]
#
#   p.save #=> false
#   p.errors.full_messages #=> ["Password must be more than 5 characters long", "Email must not be blank", 
#                                  "Please provide a valid email address.", "Name must not be blank"]
#   
#

module Validatable
  alias_method :valid_in_all_cases?, :valid? #:nodoc:

  # Returns true if no errors were added otherwise false. Only executes validations that have no :groups option specified
  def valid?(event = :validate)
    validate_recursively(event, Set.new)
  end
  
  #TODO should callbacks really affect the flow? shouldn't validations themselves do that?
  def validate_recursively(event, cleared) #:nodoc:
    return true if cleared.include?(self)
    cleared << self
    
    self.class.callbacks.execute(:before_validation, self)

    # Validatable clears the errors list when running valid_for_some_group?, so we save general errors
    # and then merge them back in after we've validated for events
    generally_valid = valid_for_group?(nil)
    general_errors = self.errors.errors.dup
    
    if respond_to?(:"valid_for_#{event}?")
      valid_for_events = send(:"valid_for_#{event}?")
      self.errors.errors.merge!(general_errors) {|key, val1, val2| val1+val2 }
      return false unless generally_valid && valid_for_events
    end
    
    return false unless generally_valid
    
    if self.respond_to?(:loaded_associations)
      return false unless self.loaded_associations.all? do |association|
        association.validate_recursively(event, cleared)
      end
    end
    
    self.class.callbacks.execute(:after_validation, self)
    return true
  end
end