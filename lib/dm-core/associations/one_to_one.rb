# TODO: make it so that a target_key is created with nullable => false if
#       @min == 1

module DataMapper
  module Associations
    module OneToOne #:nodoc:
      class Relationship < Associations::OneToMany::Relationship

        # Loads (if necessary) and returns association target
        # for given source
        #
        # @api semipublic
        def get(source, query = nil)
          return unless loaded?(source) || source_key.loaded?(source)
          super.first
        end

        # Sets and returns association target
        # for given source
        #
        # @api semipublic
        def set(source, target)
          super(source, [ target ].compact)
          target
        end

        private

        # Initializes the relationship. Always assumes target model class is
        # a camel cased association name.
        # TODO: ensure that it makes sense to make it configurable
        #
        # @api semipublic
        def initialize(name, target_model, source_model, options = {})
          target_model ||= Extlib::Inflection.camelize(name).freeze
          super
        end
      end # class Relationship
    end # module HasOne
  end # module Associations
end # module DataMapper
