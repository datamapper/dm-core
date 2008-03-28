require __DIR__ + 'relationship'

module DataMapper
  module Associations
    module BelongsTo
    
      def belongs_to(name, options = {})

        # This is like the missing piece of the puzzle...
        # a re-usable Proc assigned to the Relationship that
        # allows it to load up any AssociationSet it's passed.
        #
        # relationship = Relationship.new bla blah blah...
        # 
        # loader = lambda do |set|
        #   set.append relationship.source_resource.all(relationship.target.keys => self.loaded_set.keys)
        # end
        # 
        # relationship.loader = loader
        
        # Or maybe this syntax...
        #
        # Relationship.new(...) do |set|
        #   stuff to load
        # end
        #
        # association_set = relationship.to_set(instance)
        #
        # BAM! That's noice...        
        
        class_eval <<-EOS
          def #{name}
            #{name}_association.first
          end
          
          def #{name}=(value)
            #{name}_association.set(value)
          end
          
          private
          def #{name}_association
            @#{name}_association || @#{name}_association = AssociationSet.new(relationship, instance)
          end
        EOS
      end
    
    end # module BelongsTo
  end # module Associations
end # module DataMapper