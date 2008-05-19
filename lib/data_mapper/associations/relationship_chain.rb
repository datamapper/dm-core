module DataMapper
  module Associations
    class RelationshipChain < Relationship

      undef_method :get_parent
      undef_method :attach_parent

      def get_children(parent, options = {}, finder = :all)
        query = @query.merge(options).merge(child_key.to_query(parent_key.get(parent)))

        query[:links] = [remote_relationship]

        DataMapper.repository(parent.repository.name) do
          finder == :first ? grandchild_model.first(query) : grandchild_model.all(query)
        end
      end

      private

      attr_reader :parent_model

      def foreign_key_name
        near_relationship.foreign_key_name
      end

      def child_model
        near_relationship.child_model
      end

      def near_relationship
        parent_model.relationships[@near_relationship_name]
      end

      def remote_relationship
        near_relationship.child_model.relationships[@remote_relationship_name]
      end

      def grandchild_model
        find_const(@child_model_name)
      end

      def initialize(options)
        raise ArgumentError.new("Option +:repository_name+ required!") unless @repository_name = options.delete(:repository_name)
        raise ArgumentError.new("Option +:near_relationship_name+ required!") unless @near_relationship_name = options.delete(:near_relationship_name)
        raise ArgumentError.new("Option +:remote_relationship_name+ required!") unless @remote_relationship_name = options.delete(:remote_relationship_name)
        raise ArgumentError.new("Options +:child_model_name+ required!") unless @child_model_name = options.delete(:child_model_name)
        raise ArgumentError.new("Options +:parent_model+ required!") unless @parent_model = options.delete(:parent_model)
        raise ArgumentError.new("Unknown options for #{self.class.name}#initialize: #{options.inspect}") unless options.empty?
        @query = options.reject{ |key,val| [:class_name, :child_key, :parent_key, :min, :max].include?(key) }
      end
    end # class Relationship
  end # module Associations
end # module DataMapper
