module DataMapper
  module Adapters
    class YamlAdapter < AbstractAdapter
      require 'yaml'
      require 'fileutils'

      attr_reader :path

      def initialize(name, uri_or_options)
        super
        @path = FileUtils.mkdir_p(@options[:path])
      end

      def create(resources)
        resources.each do |resource|
          model = resource.model
          update_records(model) do |records|
            if identity_field = resource.model.identity_field(name)
              identity_field.set!(resource, records.size.succ)
            end
            records[resource.key] = resource.attributes
          end
        end

        resources.size
      end

      def read(query)
        model  = query.model
        fields = query.fields

        records = records_for(model)

        filter_records(records.values, query).map! do |record|
          model.load(fields.map { |p| record[p.name] }, query)
        end
      end

      def update(attributes, query)
        attributes = attributes.map { |p,v| [ p.name, v ] }.to_hash

        update_records(query.model) do |records|
          updated = filter_records(records.values, query)
          updated.each { |r| r.update(attributes) }
          updated.size
        end
      end

      def delete(query)
        update_records(query.model) do |records|
          deleted = filter_records(records.values, query).to_set
          records.delete_if { |_k,r| deleted.include?(r) }
          deleted.size
        end
      end

      protected

      ##
      # Retrieves all records for a model and yeilds them to a block.
      #
      # The block should make any changes to the records in-place. After
      # the block executes all the records are dumped back to the file.
      #
      # @param [Model, #to_s] model
      #   Used to determine which file to read/write to
      #
      # @yieldparam [Hash]
      #   A hash of record.key => record pairs retrieved from the file
      #
      # @api private
      def update_records(model)
        records = records_for(model)
        result = yield records
        write_records(model, records)
        result
      end

      ##
      # Read all records from a file for a model
      #
      # @param [#storage_name] model
      #   The model/name to retieve records for
      #
      # @api private
      def records_for(model)
        file = yaml_file(model)
        File.readable?(file) && YAML.load_file(file) || {}
      end

      ##
      # Writes all records to a file
      #
      # @param [#storage_name] model
      #   The model/name to write the records for
      #
      # @param [Hash] records
      #   A hash of record.key => record pairs to be written
      #
      # @api private
      def write_records(model, records)
        File.open(yaml_file(model), 'w') do |fh|
          YAML.dump(records, fh)
        end
      end

      ##
      # Given a model, gives the filename to be used for record storage
      #
      #   yaml_file(Article) #=> "/path/to/files/articles.yml"
      #
      # @param [#storage_name] model
      #   The model to be used to determine the file name.
      #
      # @api private
      def yaml_file(model)
        File.join(path, "#{model.storage_name(name)}.yml")
      end

    end # class YamlAdapter

    const_added(:YamlAdapter)
  end # module Adapters
end # module DataMapper
