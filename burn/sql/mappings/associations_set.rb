module DataMapper
  module Adapters
    module Sql
      module Mappings
        
        class AssociationsSet
          
          include Enumerable
          
          def initialize
            @set = {}
          end
          
          def <<(association)
            @set[association.name] = association            
          end
          
          def [](name)
            @set[name]
          end
          
          def each
            @set.each { |name, association| yield(association) }
          end
          
          def empty?
            @set.empty?
          end
        end
        
      end # module Mappings
    end # module Sql
  end # module Adapters
end # module DataMapper