module DataMapper
  class Migration
    class Table
      
      MAPPINGS = DataMapper::Adapters::Sql::Mappings unless defined?(MAPPINGS)
      
      attr_accessor :name
      
      def initialize(table = nil, options = {})
        @name, @options = table, options
        @columns = []
      end
      
      def self.create(table)
        table.create!
      end
      
      def self.drop(table_name)
        repository.table(klass(table_name)).drop!
      end
      
      def self.add_column(table, column, type, options = {})
        column = table.add_column column, type, options
        column.create!
      end
      
      def self.remove_column(table, column)
        column = table[column]
        column.drop!
      end
      
      def add(column, type, options = {})
        column_data = [column, type, options]
        exists? ? self.class.add_column(table, *column_data) : table.add_column(*column_data)
      end
      
      def remove(column)
        self.class.remove_column table, column
      end
      
      def rename(old_column, new_column)
        column = table[old_column]
        column.rename!(new_column)
      end
      
      def alter(column, type, options = {})
        column = table[column]
        column.type = type
        column.options = options
        column.parse_options!
        column.alter!
      end
      
      def exists?
        repository.table_exists?(klass)
      end
      
      def after_create!
        unless exists?
          table.add_column(:id, :integer, { :key => true }) unless @options[:id] == false
          self.class.create(table)
        end
      end
      
      # Rails Style
      
      def column(name, type, options = {})
        add(name, type, options)
      end
      
      # klass!
      
      def table
        @table ||= repository.table(klass)
      end
      
      def klass
        @klass ||= self.class.klass(self.name)
      end
      
      def self.klass(table)
        table_name = table.to_s
        class_name = Inflector::classify(table_name)
        klass = Inflector::constantize(class_name)
      rescue NameError
        module_eval <<-classdef
        class ::#{class_name} < DataMapper::Base
        end
        classdef
        klass = eval("#{class_name}")
      ensure
        klass
      end
      
    end
    
    class << self
      
      def up; end
      
      def down; end
      
      def migrate(direction = :up)
        send(direction)
      end
      
      def table(table = nil, options = {}, &block)
        if table && block
          table = DataMapper::Migration::Table.new(table, options)
          table.instance_eval &block
          table.after_create!
        else
          return DataMapper::Migration::Table
        end
      end
      
      # Rails Style
      
      def create_table(table_name, options = {}, &block)
        new_table = table.new(table_name, options)
        yield new_table
        new_table.after_create!
      end
      
      def drop_table(table_name)
        table.drop(table_name)
      end
      
      def add_column(table_name, column, type, options = {})
        table table_name do
          add column, type, options
        end
      end
      
      def rename_column(table_name, old_column_name, new_column_name)
        table table_name do
          rename old_column_name, new_column_name
        end
      end
      
      def change_column(table_name, column_name, type, options = {})
        table table_name do
          alter column_name, type, options
        end
      end
      
      def remove_column(table_name, column)
        table table_name do
          remove column
        end
      end
    end
  end
  
end
