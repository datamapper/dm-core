require 'pathname'
require 'yaml'

module DataMapper
  module Adapters
    class YamlAdapter < AbstractAdapter
      # @api semipublic
      def create(resources)
        update_records(resources.first.model) do |records|
          resources.each do |resource|
            initialize_serial(resource, records.size.succ)
            records << resource.attributes(:field)
          end
        end
      end

      # @api semipublic
      def read(query)
        query.filter_records(records_for(query.model).dup)
      end

      # @api semipublic
      def update(attributes, collection)
        attributes = attributes_as_fields(attributes)

        update_records(collection.model) do |records|
          records_to_update = collection.query.filter_records(records.dup)
          records_to_update.each { |resource| resource.update(attributes) }.size
        end
      end

      # @api semipublic
      def delete(collection)
        update_records(collection.model) do |records|
          records_to_delete = collection.query.filter_records(records.dup)
          records.replace(records - records_to_delete)
          records_to_delete.size
        end
      end

      private

      # @api semipublic
      def initialize(name, options = {})
        super
        (@path = Pathname(@options[:path]).freeze).mkpath
      end

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

      # Read all records from a file for a model
      #
      # @param [#storage_name] model
      #   The model/name to retieve records for
      #
      # @api private
      def records_for(model)
        file = yaml_file(model)
        file.readable? && YAML.load_file(file) || []
      end

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
        yaml_file(model).open('w') do |fh|
          YAML.dump(records, fh)
        end
      end

      # Given a model, gives the filename to be used for record storage
      #
      # @example
      #   yaml_file(Article) #=> "/path/to/files/articles.yml"
      #
      # @param [#storage_name] model
      #   The model to be used to determine the file name.
      #
      # @api private
      def yaml_file(model)
        @path / "#{model.storage_name(name)}.yml"
      end

    end # class YamlAdapter

    const_added(:YamlAdapter)
  end # module Adapters
end # module DataMapper
