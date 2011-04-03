module DataMapper

  # A {SubjectSet} that keeps track of relationships defined in a {Model}
  #
  class RelationshipSet < SubjectSet

    # A list of all relationships in this set
    #
    # @deprecated use DataMapper::RelationshipSet#each or DataMapper::RelationshipSet#to_a instead
    #
    # @return [Array]
    #    a list of all relationships in the set
    #
    # @api semipublic
    def values
      warn "#{self.class}#values is deprecated. Use #{self.class}#each or #{self.class}#to_a instead: #{caller.first}"
      to_a
    end

    # A list of all relationships in this set
    #
    # @deprecated use DataMapper::RelationshipSet#each instead
    #
    # @yield [DataMapper::Associations::Relationship]
    #    all relationships in the set
    #
    # @yieldparam [DataMapper::Associations::Relationship] relationship
    #    a relationship in the set
    #
    # @return [RelationshipSet] self
    #
    # @api semipublic
    def each_value
      warn "#{self.class}#each_value is deprecated. Use #{self.class}#each instead: #{caller.first}"
      each { |relationship| yield(relationship) }
      self
    end

    # Check wether this RelationshipSet includes an entry with the given name
    #
    # @deprecated use DataMapper::RelationshipSet#named? instead
    #
    # @param [#to_s] name
    #   the name of the entry to look for
    #
    # @return [Boolean]
    #   true if the set contains a relationship with the given name
    #
    # @api semipublic
    def key?(name)
      warn "#{self.class}#key? is deprecated. Use #{self.class}#named? instead: #{caller.first}"
      named?(name)
    end

    # Check wether this RelationshipSet includes an entry with the given name
    #
    # @deprecated use DataMapper::RelationshipSet#named? instead
    #
    # @param [#to_s] name
    #   the name of the entry to look for
    #
    # @return [Boolean]
    #   true if the set contains a relationship with the given name
    #
    # @api semipublic
    def has_key?(name)
      warn "#{self.class}#has_key? is deprecated. Use #{self.class}#named? instead: #{caller.first}"
      named?(name)
    end

  end # class RelationshipSet
end # module DataMapper
