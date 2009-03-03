# TODO: make it so that a child_key is created with nullable => false if
#       @min == 1

module DataMapper
  module Associations
    module OneToOne #:nodoc:
      class Relationship < Associations::OneToMany::Relationship

        # Loads (if necessary) and returns association child
        # for given parent
        #
        # @api semipublic
        def get(parent, query = nil)
          super.first
        end

        # Sets and returns association child
        # for given parent
        #
        # @api semipublic
        def set(parent, child)
          super(parent, [ child ].compact)
          child
        end

        private

        # Initializes the relationship. Always assumes child model class is
        # a camel cased association name.
        # TODO: ensure that it makes sense to make it configurable
        #
        # @api semipublic
        def initialize(name, child_model, parent_model, options = {})
          child_model ||= Extlib::Inflection.camelize(name).freeze
          super
        end
      end # class Relationship
    end # module HasOne
  end # module Associations
end # module DataMapper
