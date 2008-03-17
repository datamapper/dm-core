module DataMapper
  
  module Associations
    
    # Reference is an abstract-class providing the boiler-plate for
    # the association proxies (ie: HasManyAssociation::Set, or
    # HasOneAssociation::Instance)
    # The proxies need to access the defining Association instances
    # to obtain mapping information. This class provides convenient
    # access to said Association.
    #
    # EXAMPLE:
    #   class Zoo
    #     has_many :exhibits
    #   end
    # The +has_many+ declaration instantiates a
    # DataMapper::Associations::HasManyAssociation and adds it to the
    # DataMapper::Adapters::Sql::Mappings::Table#associations array for
    # the Table representing Zoo.
    #
    #   Zoo.new.exhibits
    # +exhibits+ above returns an instance of
    # DataMapper::Associations::HasManyAssociation::Set. This instance
    # needs to access the actual HasManyAssociation instance in order
    # to access the mapping information within. The DataMapper::Associations::Reference
    # abstract-class for the Set provides the Reference#association method in order to
    # provide easy access to this information.
    class Reference
  
      # +instance+ is a mapped object instance. ie: #<Zoo:0x123456 ...>
      # +association_name+ is the Symbol used to look up the Association
      # instance within the DataMapper::Adapters::Sql::Mappings::Table 
      def initialize(instance, association_name)
        @instance, @association_name = instance, association_name.to_sym
        @instance.loaded_associations << self
      end
  
      # #association provides lazily initialized access to the declared
      # Association.
      def association
        @association || (@association = @instance.database_context.table(@instance.class).associations[@association_name])
      end
  
    end
  end

end