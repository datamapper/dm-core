module DataMapper
  module Associations
    module HasManyThrough
      OPTIONS = [ :class_name, :remote_name ]

      private

      def has_many_through(name, options = {})
        raise ArgumentError, "+name+ should be a Hash, but was #{name.class}", caller     unless Hash === name
        raise ArgumentError, "+options+ should be a Hash, but was #{options.class}", caller unless Hash   === options

        near_relationship_name = name.keys.first
        remote_relationship_name = options.fetch(:remote_name, name.values.last)
        child_model_name = options.fetch(:class_name, DataMapper::Inflection.classify(name.values.first))

        rel = relationships(repository.name)[name.values.first] = RelationshipChain.new(:child_model_name => child_model_name,
                                                                                        :parent_model => self,
                                                                                        :repository_name => repository.name,
                                                                                        :near_relationship_name => near_relationship_name,
                                                                                        :remote_relationship_name => remote_relationship_name)

        class_eval <<-EOS, __FILE__, __LINE__
          def #{name.values.first}
            #{name.values.first}_association.nil? ? nil : #{name.values.first}_association
          end
          
          def #{name.values.first}=(children)
            #{name.values.first}_association.replace(children)
          end
          
          private
          
          def #{name.values.first}_association
            @#{name.values.first}_association ||= begin
              relationship = self.class.relationships(repository.name)[#{name.values.first.inspect}]
              raise ArgumentError.new("Relationship #{name.values.first} does not exist") unless relationship
              association = Proxy.new(relationship, self)
              parent_associations << association
              association
            end
          end
        EOS

        rel
      end

      class Proxy
        instance_methods.each { |m| undef_method m unless %w[ __id__ __send__ class kind_of? should should_not ].include?(m) }

        def all(options={})
          options.empty? ? children : @relationship.get_children(@parent_resource,options,:all)
        end
        
        def first(options={})
          options.empty? ? children.first : @relationship.get_children(@parent_resource,options,:first)
        end

        def save
        end

        private

        def initialize(relationship, parent_resource)
          @relationship    = relationship
          @parent_resource = parent_resource
        end

        def children
          @children ||= @relationship.get_children(@parent_resource)
        end

        def method_missing(method, *args, &block)
          children.__send__(method, *args, &block)
        end
      end # class Proxy
    end # module HasManyThrough
  end # module Associations
end # module DataMapper
