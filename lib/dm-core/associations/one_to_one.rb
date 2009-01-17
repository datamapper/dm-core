# TODO: make it so that a child_key is created with nullable => false if
#       @min == 1

module DataMapper
  module Associations
    module OneToOne
      class Relationship < DataMapper::Associations::OneToMany::Relationship
        private

        # TODO: document
        # @api semipublic
        def initialize(name, child_model, parent_model, options = {})
          child_model ||= Extlib::Inflection.camelize(name)
          super
        end

        # TODO: document
        # @api semipublic
        def create_accessor
          return if parent_model.instance_methods(false).include?(name)

          parent_model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            public  # TODO: make this configurable
            def #{name}
              #{name}_helper.first
            end
          RUBY
        end

        # TODO: document
        # @api semipublic
        def create_mutator
          return if parent_model.instance_methods(false).include?("#{name}=")

          parent_model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            public  # TODO: make this configurable
            def #{name}=(child_resource)
              #{name}_helper.replace(child_resource.nil? ? [] : [ child_resource ])
            end
          RUBY
        end
      end # class Relationship
    end # module HasOne
  end # module Associations
end # module DataMapper
