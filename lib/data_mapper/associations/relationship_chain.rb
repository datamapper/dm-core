module DataMapper
  module Associations
    class RelationshipChain < Relationship

      undef_method :get_parent
      undef_method :attach_parent

      def get_children(parent, options = {}, finder = :all)
        query = @query.merge(options).merge(child_key.to_query(parent_key.get(parent)))

        query[:links] = links

        DataMapper.repository(parent.repository.name) do
          finder == :first ? grandchild_model.first(query) : grandchild_model.all(query)
        end
      end

      def child_model
        near_relationship.child_model
      end

      private

      def near_relationship
        parent_model.relationships[@near_relationship_name]
      end

      def links
        if RelationshipChain === remote_relationship
          remote_relationship.instance_eval do links end + [remote_relationship.instance_eval do near_relationship end]
        else
          [remote_relationship]
        end
      end

      def extra_links
        if RelationshipChain === remote_relationship
          []
        else
          []
        end
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
        raise ArgumentError.new("Options +:parent_model_name+ required!") unless @parent_model_name = options.delete(:parent_model_name)
        @parent_properties = options.delete(:parent_key)
        @child_properties = options.delete(:child_key)
        raise ArgumentError.new("Unknown options for #{self.class.name}#initialize: #{options.inspect}") unless options.empty?
        @query = options.reject{ |key,val| [:class_name, :child_key, :parent_key, :min, :max].include?(key) }
        @extra_links = []

        @name = near_relationship.name
      end
    end # class Relationship
  end # module Associations
end # module DataMapper
