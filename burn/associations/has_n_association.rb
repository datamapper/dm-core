module DataMapper                        
  
  class ForeignKeyNotFoundError < StandardError; end
  class AssociationProtectedError < StandardError; end
    
  module Associations
    
    class HasNAssociation
      
      attr_reader :options
      
      OPTIONS = [
        :class,
        :class_name,
        :foreign_key,
        :dependent
      ]
      
      def initialize(klass, association_name, options)
        @constant = klass
        @adapter = repository.adapter
        @table = @adapter.table(klass)
        @association_name = association_name.to_sym
        @options = options || Hash.new
        
        define_accessor(klass)
        
        Persistable::dependencies.add(associated_constant_name) do |klass|
          @foreign_key_column = associated_table[foreign_key_name]
          
          unless @foreign_key_column
            associated_constant.property(foreign_key_name, foreign_key_type)
          
            @foreign_key_column = associated_table[foreign_key_name]
          
            if @foreign_key_column.nil?
              raise ForeignKeyNotFoundError.new(<<-EOS.compress_lines)
                key_table => #{key_table.inspect},
                association_table => #{associated_table.inspect},
                association_name => #{name},
                foreign_key_name => #{foreign_key_name.inspect},
                foreign_key_type => #{foreign_key_type.inspect},
                constant => #{constant.inspect},
                associated_constant => #{associated_constant.inspect}
              EOS
            end
          end
        end
      end
      
      def name
        @association_name
      end

      def constant
        @constant
      end
      
      def associated_constant
        @associated_constant || @associated_constant = Kernel.const_get(associated_constant_name)
      end
      
      def associated_constant_name
        @associated_constant_name || begin
          
          if @options.has_key?(:class) || @options.has_key?(:class_name)
            @associated_constant_name = (@options[:class] || @options[:class_name])
            
            if @associated_constant_name.kind_of?(String)
              @associated_constant_name = Inflector.classify(@associated_constant_name)
            elsif @associated_constant_name.kind_of?(Class)
              @associated_constant_name = @associated_constant_name.name
            end  
          else
            @associated_constant_name = Inflector.classify(@association_name)
          end
          
          @associated_constant_name
        end
        
      end
      
      def primary_key_column
        @primary_key_column || @primary_key_column = key_table.key
      end
      
      def foreign_key_column
        @foreign_key_column
      end
      
      def foreign_key_name
        @foreign_key_name || @foreign_key_name = (@options[:foreign_key] || key_table.default_foreign_key)
      end
      
      def foreign_key_type
        @foreign_key_type || @foreign_key_type = key_table.key.type
      end
      
      def key_table
        @key_table || @key_table = @adapter.table(constant)
      end
      
      def associated_table
        @association_table || @association_table = @adapter.table(associated_constant)
      end
      
      def associated_columns
        associated_table.columns.reject { |column| column.lazy? }
      end
      
      def complementary_association
        @complementary_association || begin
          @complementary_association = associated_table.associations.find do |mapping|
            mapping.is_a?(BelongsToAssociation) && 
            mapping.foreign_key_column == foreign_key_column &&
            mapping.key_table.name == key_table.name
          end
          
          if @complementary_association
            class << self
              attr_accessor :complementary_association
            end
          end
          
          return @complementary_association
        end
      end
      
      def finder_options
        @finder_options || @finder_options = @options.reject { |k,v| self.class::OPTIONS.include?(k) }
      end
      
      def to_sql
        "JOIN #{associated_table.to_sql} ON #{foreign_key_column.to_sql(true)} = #{primary_key_column.to_sql(true)}"
      end
      
      def activate!(force = false)
        foreign_key_column
      end
    end
    
  end
end
