require 'data_mapper/associations/reference'
require 'data_mapper/associations/has_many_association'
require 'data_mapper/associations/belongs_to_association'
require 'data_mapper/associations/has_and_belongs_to_many_association'

module DataMapper
  module Associations
    
    # Extends +base+ with methods for setting up associations between different models.
    def self.included(base)
      base.extend(ClassMethods)
    end
    
    module ClassMethods
      
      def associations
        @associations
      end
      
      # Adds the following methods for query of a single associated object:
      # * <tt>collection(</tt> - returns a set containing the associated objects. Returns
      #   an empty set if no objects are found.
      # * <tt>collection << object</tt> - adds an object to the collection.
      # * <tt>collection = [objects]</tt> - replaces the collections content by deleting and
      #   adding objects as appropriate.
      # * <tt>collection.empty?</tt> - returns +true+ if there is no associated objects.
      # * <tt>collection.size</tt> - returns the number of associated objects.
      #
      # Options are:
      # * <tt>:class</tt> - specify the class name of the association. So has_many :animals will by
      #   default be linked to the Animal class, but if you want the association to use a
      #   different class, you'll have to specify it with this option. DM also lets you specify
      #   this with <tt>:class_name</tt>, for AR compability.
      # * <tt>:foreign_key</tt> - specify the foreign key used for the association. By default
      #   this is guessed to be the name of this class in lower-case and _id suffixed.
      # * <tt>:dependent</tt> - if set to :destroy, the associated objects have their destroy! methods
      #   called in a chain meaning all callbacks are also called for each object.
      #   if set to :delete, the associated objects are deleted from the database
      #   without their callbacks being triggered.
      #   if set to :protect and the collection is not empty an AssociatedProtectedError will be raised.
      #   if set to :nullify, the associated objects foreign key is set to NULL.
      #   default is :nullify
      #
      # Option examples:
      #   has_many :favourite_fruits, :class => 'Fruit', :dependent => :destroy
      def has_many(association_name, options = {})
        #self.associations << HasManyAssociation.new(self, association_name, options)
      end
      
      # Adds the following methods for query of a single associated object:
      # * <tt>association(</tt> - returns the associated object. Returns an empty set if no
      #   object is found.
      # * <tt>association=(associate)</tt> - assigns the associate object, extracts the
      #   primary key, and sets it as the foreign key.
      # * <tt>association.nil?</tt> - returns +true+ if there is no associated object.
      #
      # The declaration can also include an options hash to specialize the behavior of the
      # association.
      #
      # Options are:
      # * <tt>:class</tt> - specify the class name of the association. So has_one :animal will by
      #   default be linked to the Animal class, but if you want the association to use a
      #   different class, you'll have to specify it with this option. DM also lets you specify
      #   this with <tt>:class_name</tt>, for AR compability.
      # * <tt>:foreign_key</tt> - specify the foreign key used for the association. By default
      #   this is guessed to be the name of this class in lower-case and _id suffixed.
      # * <tt>:dependent</tt> - has_one is secretly a has_many so this option performs the same
      #   as the has_many
      #
      # Option examples:
      #   has_one :favourite_fruit, :class => 'Fruit', :foreign_key => 'devourer_id'
      def has_one(association_name, options = {})
        #self.associations << HasManyAssociation.new(self, association_name, options)
      end
      
      # Adds the following methods for query of a single associated object:
      # * <tt>association(</tt> - returns the associated object. Returns an empty set if no
      #   object is found.
      # * <tt>association=(associate)</tt> - assigns the associate object, extracts the
      #   primary key, and sets it as the foreign key.
      # * <tt>association.nil?</tt> - returns +true+ if there is no associated object.
      # * <tt>build_association</tt> - builds a new object of the associated type, without
      #   saving it to the database.
      # * <tt>create_association</tt> - creates and saves a new object of the associated type.
      def belongs_to(association_name, options = {})
        #self.associations << BelongsToAssociation.new(self, association_name, options)
      end
      
      # Associates two classes via an intermediate join table.
      #
      # Options are:
      # * <tt>:dependent</tt> - if set to :destroy, the associated objects have their destroy! methods
      #   called in a chain meaning all callbacks are also called for each object.  Beware that this
      #   is a cascading delete and will affect all records that have a remote relationship with the
      #   record being destroyed!
      #   if set to :delete, the associated objects are deleted from the database without their
      #   callbacks being triggered.  This does NOT cascade the deletes.  All associated objects will
      #   have their relationships removed from other records before being deleted.  The record calling
      #   destroy will only delete those records directly associated to it.
      #   if set to :protect and the collection is not empty an AssociatedProtectedError will be raised.
      #   if set to :nullify, the join table will have the relationship records removed which is
      #   effectively nullifying the foreign key.
      #   default is :nullify
      def has_and_belongs_to_many(association_name, options = {})
        #self.associations << HasAndBelongsToManyAssociation.new(self, association_name, options)
      end
      
    end
    
  end
end
