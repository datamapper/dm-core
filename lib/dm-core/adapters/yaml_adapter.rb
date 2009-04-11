module DataMapper
  module Adapters
    class YamlAdapter < AbstractAdapter
      require 'yaml'
      require 'fileutils'

      attr_reader :path

      def initialize(name, options = {})
        super
        @path = FileUtils.mkdir_p(@options[:path])
      end

      def create(resources)
        update_records(resources.first.model) do |records|
          resources.each do |resource|
            initialize_identity_field(resource, records.size.succ)
            records[resource.key] = resource.attributes(:field)
          end
        end
      end

      def read(query)
        records = records_for(query.model)
        filter_records(records.values, query)
      end

      def update(attributes, collection)
        query      = collection.query
        attributes = attributes_as_fields(attributes)

        update_records(collection.model) do |records|
          updated = filter_records(records.values, query)
          updated.each { |r| r.update(attributes) }
        end
      end

      def delete(collection)
        query = collection.query

        update_records(collection.model) do |records|
          records_to_delete = filter_records(records.values, query).to_set
          records.delete_if { |_k,r| records_to_delete.include?(r) }
          records_to_delete
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
