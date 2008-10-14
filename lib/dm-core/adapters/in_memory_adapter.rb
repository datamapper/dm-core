module DataMapper
  module Adapters
    class InMemoryAdapter < AbstractAdapter
      # TODO: document
      # @api semipublic
      def create(resources)
        repository_name = self.name

        resources.each do |resource|
          # TODO: make a model.identity_field method
          if identity_field = resource.model.key(repository.name).detect { |p| p.serial? }
            identity_field.set!(resource, @records[resource.model].size.succ)
          end

          @records[resource.model][resource.key] = resource.dirty_attributes.map { |p,v| [ p.field(repository_name), v ] }.to_hash
        end.size # just return the number of records
      end

      # TODO: document
      # @api semipublic
      def update(attributes, query)
        repository_name = query.repository.name
        records         = @records[query.model]
        attributes      = attributes.map { |p,v| [ p.field(repository_name), v ] }.to_hash

        read_many(query).each do |resource|
          records[resource.key].update(attributes)
        end.size
      end

      # TODO: document
      # @api semipublic
      def read_one(query)
        read(query, query.model, false)
      end

      # TODO: document
      # @api semipublic
      def read_many(query)
        Collection.new(query) do |set|
          read(query, set, true)
        end
      end

      # TODO: document
      # @api semipublic
      def delete(query)
        records = @records[query.model]

        read_many(query).each do |resource|
          records.delete(resource.key)
        end.size
      end

      private

      # TODO: document
      # @api semipublic
      def initialize(name, uri_or_options)
        super
        @records = Hash.new { |hash,model| hash[model] = {} }
      end

      # TODO: document
      # @api private
      def read(query, set, many = true)
        repository_name = query.repository.name
        conditions      = query.conditions

        # find all matching records
        results = @records[query.model].values.select do |attributes|
          conditions.all? do |tuple|
            operator, property, bind_value = *tuple

            value = attributes[property.field(repository_name)]

            case operator
              when :eql, :in then equality_comparison(bind_value, value)
              when :not      then !equality_comparison(bind_value, value)
              when :like     then Regexp.new(bind_value) =~ value
              when :gt       then !value.nil? && value >  bind_value
              when :gte      then !value.nil? && value >= bind_value
              when :lt       then !value.nil? && value <  bind_value
              when :lte      then !value.nil? && value <= bind_value
            end
          end
        end

        # sort the results
        if query.order.any?
          results = sorted_results(results, query.order, repository_name)
        end

        # limit the results
        if query.limit || query.offset > 0
          results = results[query.offset, query.limit || results.size]
        end

        properties = query.fields

        # load a Resource for each result
        results.each do |attributes|
          values = properties.map { |p| attributes[p.field(repository_name)] }
          many ? set.load(values) : (break set.load(values, query))
        end
      end

      # TODO: document
      # @api private
      def equality_comparison(bind_value, value)
        case bind_value
          when Array, Range then bind_value.include?(value)
          when NilClass     then value.nil?
          else                   bind_value == value
        end
      end

      # TODO: document
      # @api private
      def sorted_results(results, order, repository_name)
        # get the field if it's sorted in descending/ascending order
        field_order = field_order(order, repository_name)

        # sort results by each field
        results.sort do |a,b|
          cmp = 0
          field_order.each do |(field,descending)|
            cmp = descending ? b[field] <=> a[field] : a[field] <=> b[field]
            next if cmp == 0
          end
          cmp
        end
      end

      # TODO: document
      # @api private
      def field_order(order, repository_name)
        order.map do |item|
          property, descending = nil, false

          case item
            when Property
              property = item
            when Query::Direction
              property  = item.property
              descending = true if item.direction == :desc
          end

          [ property.field(repository_name), descending ]
        end
      end
    end
  end
end
