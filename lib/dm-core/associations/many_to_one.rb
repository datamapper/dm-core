module DataMapper
  module Associations
    module ManyToOne #:nodoc:
      # Relationship class with implementation specific
      # to n side of 1 to n association
      class Relationship < Associations::Relationship
        alias source_repository_name child_repository_name
        alias source_model           child_model
        alias source_key             child_key

        alias target_repository_name parent_repository_name
        alias target_model           parent_model
        alias target_key             parent_key

        # Returns a hash of conditions that scopes query that fetches
        # source object
        #
        # @returns [Hash]  Hash of conditions that scopes query
        #
        # @api private
        def source_scope(source)
          # TODO: do not build the query with source_key/target_key.. use
          # source_reader/target_reader.  The query should be able to
          # translate those to source_key/target_key inside the adapter,
          # allowing adapters that don't join on PK/FK to work too.

          # TODO: when target is a Collection, and it's query includes an
          # offset/limit, use it as a subquery to scope the results, rather
          # than (potentially) lazy-loading the Collection and getting
          # each resource key

          # TODO: handle compound keys when OR conditions supported
          source_values = Array(source).map { |r| source_key.get(r).first }.compact
          target_key.zip(source_values).to_hash
        end

        # Creates and returns Query instance that fetches
        # target resource (ex.: author) for given source
        # source resource (ex.: article)
        #
        # @param  source  [Array<DataMapper::Resource>]
        #   collection (possibly with a single item) of source objects
        #
        # @api semipublic
        def query_for(source)
          Query.new(DataMapper.repository(target_repository_name), target_model, query.merge(source_scope(source)))
        end

        # Loads and returns association target (ex.: author) for given source resource
        # (ex.: article)
        #
        # @param  source  [DataMapper::Resource]
        #   Child object (ex.: instance of article)
        # @param  query  [DataMapper::Query]
        #   Query options
        #
        # @api semipublic
        def get(source, query = nil)
          return unless loaded?(source) || lazy_load(source)

          resource = get!(source)

          if query.nil?
            resource
          else
            # TODO: when Resource can be matched against conditions
            # easily, return the resource if it matches, otherwise
            # return nil
            if resource.saved?
              target_model.first(resource.to_query.update(query))
            else
              # TODO: remove this condition when in-memory objects
              # can be matched
              resource
            end
          end
        end

        # Sets value of association target (ex.: author) for given source resource
        # (ex.: article)
        #
        # @param source [DataMapper::Resource]
        #   Child object (ex.: instance of article)
        #
        # @param source [DataMapper::Resource]
        #   Parent object (ex.: instance of author)
        #
        # @api semipublic
        def set(source, target)
          source_key.set(source, target_key.get(target))
          set!(source, target)
        end

        private

        # Initializes the relationship, always using max cardinality of 1.
        # @api semipublic
        def initialize(name, source_model, target_model, options = {})
          target_model ||= Extlib::Inflection.camelize(name).freeze
          options        = options.merge(:min => 0, :max => 1)
          super
        end

        # Dynamically defines reader method for source side of association
        # (for instance, method article for model Paragraph)
        #
        # @api semipublic
        def create_reader
          return if source_model.instance_methods(false).any? { |m| m.to_sym == name }

          source_model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            public  # TODO: make this configurable

            # FIXME: if the writer is used, caching nil in the ivar
            # and then the FK(s) are set, the cache in the writer should
            # be cleared.

            def #{name}(query = nil)                          # def article(query = nil)
              relationships[#{name.inspect}].get(self, query) #   relationships["article"].get(self, query)
            end                                               # end
          RUBY
        end

        # Dynamically defines writer method for source side of association
        # (for instance, method article= for model Paragraph)
        #
        # @api semipublic
        def create_writer
          writer_name = "#{name}=".to_sym

          return if source_model.instance_methods(false).any? { |m| m.to_sym == writer_name }

          source_model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            public  # TODO: make this configurable
            def #{writer_name}(target)                         # def article=(target)
              relationships[#{name.inspect}].set(self, target) #   relationships["article"].set(self, target)
            end                                                # end
          RUBY
        end

        # Loads association target and sets resulting value on
        # given source resource
        #
        # @api private
        def lazy_load(source)
          # TODO: use SEL to load the related record for every resource in
          # the collection the target belongs to

          # lazy load if the source key is not nil for at least one source
          if Array(source).all? { |r| source_key.get(r).nil? }
            return
          end

          query_for = query_for(source)

          if query
            query_for.update(query)
          end

          unless target = target_model.first(query_for)
            return
          end

          # if successful should always return the target, otherwise nil
          set!(source, target)
        end

        # Prefix used to build name of default source key
        #
        # @api private
        def property_prefix
          name
        end
      end # class Relationship
    end # module ManyToOne
  end # module Associations
end # module DataMapper
