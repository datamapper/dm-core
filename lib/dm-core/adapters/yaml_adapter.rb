module DataMapper::Adapters

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

    def read_one(query)
      read_many(query).first
    end

    def read_many(query)
      model = query.model

      records = records_for(model).values
      filter_records(records, query)

      fields = query.fields
      records.map! do |record|
        model.load(fields.map { |p| record[p.name] }, query)
      end
    end

    def update(attributes, query)
      update_records(query.model) do |records|
        filter_records(records.dup.values, query).each do |record|
          attributes.each { |p,v| records[records.index(record)][p.name] = v }
        end
      end.size
    end

    def delete(query)
      update_records(query.model) do |records|
        filter_records(records.dup.values, query).each do |record|
          records.delete_if { |k,r| r == record }
        end
      end.size
    end

    protected

    ##
    # Retrieves all records for a model and yeilds them to a block.
    # The block should make any changes to the records in-place. After
    # the block executes all the records are dumped back to the file.
    #
    # @param [DataMapper::Model, #to_s] model
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
    # @param [#to_s] model
    #   The model/name to retieve records for
    #
    # @api private
    def records_for(model)
      if File.readable? yaml_file(model)
        YAML.load_file( yaml_file(model) ) || Hash.new({})
      else
        Hash.new({})
      end
    end

    ##
    # Writes all records to a file
    #
    # @param [#to_s] model
    #   The model/name to write the records for
    #
    # @param [Hash] records
    #   A hash of record.key => record pairs to be written
    #
    # @api private
    def write_records(model, records)
      File.open(yaml_file(model), 'w') { |fh|
        YAML.dump(records, fh)
      }
    end

    ##
    # Given a model, gives the filename to be used for record storage
    #
    #     yaml_file(Article) #=> "/path/to/files/Article.yml"
    #
    # @param [#to_s] model
    #   The model/name to be used to determine the file name. Usually a
    #   DataMapper::Model class, but can be anything
    #
    def yaml_file(model)
      File.join(path, "#{model}.yml")
    end

  end
end

