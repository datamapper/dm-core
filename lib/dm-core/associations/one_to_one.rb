module DataMapper
  module Associations
    module OneToOne #:nodoc:
      class Relationship < Associations::Relationship
        instance_methods.each { |method| undef_method method unless %w[ __id__ __send__ send class dup object_id kind_of? instance_of? respond_to? equal? assert_kind_of should should_not instance_variable_set instance_variable_get extend ].include?(method.to_s) }

        # Loads (if necessary) and returns association target
        # for given source
        #
        # @api semipublic
        def get(source, other_query = nil)
          assert_kind_of 'source', source, source_model

          return unless loaded?(source) || source_key.get(source).all?
          @relationship.get(source, other_query).first
        end

        # Sets and returns association target
        # for given source
        #
        # @api semipublic
        def set(source, target)
          assert_kind_of 'source', source, source_model
          assert_kind_of 'target', target, target_model, NilClass

          @relationship.set(source, [ target ].compact)
          target
        end

        # TODO: document
        # @api public
        def kind_of?(klass)
          super || @relationship.kind_of?(klass)
        end

        # TODO: document
        # @api public
        def instance_of?(klass)
          super || @relationship.instance_of?(klass)
        end

        # TODO: document
        # @api public
        def respond_to?(method, include_private = false)
          super || @relationship.respond_to?(method, include_private)
        end

        private

        # Initializes the relationship. Always assumes target model class is
        # a camel cased association name.
        #
        # @api semipublic
        def initialize(name, target_model, source_model, options = {})
          klass = options.key?(:through) ? ManyToMany::Relationship : OneToMany::Relationship
          target_model ||= Extlib::Inflection.camelize(name).freeze
          @relationship = klass.new(name, target_model, source_model, options)
        end

        # TODO: document
        # @api private
        def method_missing(method, *args, &block)
          @relationship.send(method, *args, &block)
        end
      end # class Relationship
    end # module HasOne
  end # module Associations
end # module DataMapper
