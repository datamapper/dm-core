require 'data_mapper/associations/has_n_association'

module DataMapper
  module Associations

    class HasManyAssociation < HasNAssociation

      def dependency
        @options[:dependent]
      end

      # Define the association instance method (i.e. Project#tasks)
      def define_accessor(klass)
        klass.class_eval <<-EOS
          def #{@association_name}
            @#{@association_name} || (@#{@association_name} = DataMapper::Associations::HasManyAssociation::Set.new(self, #{@association_name.inspect}))
          end

          def #{@association_name}=(value)
            #{@association_name}.set(value)
          end

          private
          def #{@association_name}_keys=(value)
            #{@association_name}.clear

            associated_constant = #{@association_name}.association.associated_constant
            associated_table = #{@association_name}.association.associated_table
            associated_constant.all(associated_table.key => [*value]).each do |entry|
              #{@association_name} << entry
            end
          end
        EOS
      end

      def to_disassociate_sql
        "UPDATE #{associated_table.to_sql} SET #{foreign_key_column.to_sql} = NULL WHERE #{foreign_key_column.to_sql} = ?"
      end

      def to_delete_sql
        "DELETE FROM #{associated_table.to_sql} WHERE #{foreign_key_column.to_sql} = ?"
      end

      def instance_variable_name
        class << self
          attr_reader :instance_variable_name
        end

        @instance_variable_name = "@#{@association_name}"
      end

      class Set < Associations::Reference

        include Enumerable

        # Returns true if the association has zero items
        def nil?
          loaded_members.blank?
        end

        def dirty?(cleared = ::Set.new)
          loaded_members.any? { |member| cleared.include?(member) || member.dirty?(cleared) }
        end

        def validate_recursively(event, cleared)
          loaded_members.all? { |member| cleared.include?(member) || member.validate_recursively(event, cleared) }
        end

        def save_without_validation(database_context, cleared)

          adapter = @instance.database_context.adapter

          members = loaded_members

          adapter.connection do |db|

            sql = association.to_disassociate_sql
            parameters = [@instance.key]

            member_keys = members.map { |member| member.key }.compact

            unless member_keys.empty?
              sql << " AND #{association.associated_table.key} NOT IN ?"
              parameters << member_keys
            end

            db.create_command(sql).execute_non_query(*parameters)
          end

          unless members.blank?

            setter_method = "#{@association_name}=".to_sym
            ivar_name = association.foreign_key_column.instance_variable_name
            original_value_name = association.foreign_key_column.name

            members.each do |member|
              member.original_values.delete(original_value_name)
              member.instance_variable_set(ivar_name, @instance.key)
              @instance.database_context.adapter.save_without_validation(database_context, member, cleared)
            end
          end
        end

        def each
          items.each { |item| yield item }
        end

        # Builds a new item and returns it.
        def build(options)
          item = association.associated_constant.new(options)
          self << item
          item
        end

        # Builds and saves a new item, then returns it.
        def create(options)
          item = build(options)
          item.save
          item
        end

        def set(value)
          values = value.is_a?(Enumerable) ? value : [value]
          @items = Support::TypedSet.new(association.associated_constant)
          values.each do |item|
            self << item
          end
        end

        # Adds a new item to the association. The entire item collection is then returned.
        def <<(member)
          shallow_append(member)

          if complement = association.complementary_association
            member.send("#{complement.name}_association").shallow_append(@instance)
          end

          return self
        end

        def clear
          @pending_members = nil
          @items = Support::TypedSet.new(association.associated_constant)
        end

        def shallow_append(member)
          if @items
            self.items << member
          else
            pending_members << member
          end
          return self
        end

        def method_missing(symbol, *args, &block)
          if items.respond_to?(symbol)
            items.send(symbol, *args, &block)
          elsif association.associated_table.associations.any? { |assoc| assoc.name == symbol }
            results = []
            each do |item|
              unless (val = item.send(symbol)).blank?
                results << (val.is_a?(Enumerable) ? val.entries : val)
              end
            end
            results.flatten
          elsif items.size == 1 && items.entries.first.respond_to?(symbol)
            items.entries.first.send(symbol, *args, &block)
          else
            super
          end
        end

        def respond_to?(symbol)
          items.respond_to?(symbol) || super
        end

        def reload!
          @items = nil
        end

        def items
          @items || begin
            if @instance.loaded_set.nil?
              @items = Support::TypedSet.new(association.associated_constant)
            else
              associated_items = fetch_sets

              # This is where @items is set, by calling association=,
              # which in turn calls HasManyAssociation::Set#set.
              association_ivar_name = association.instance_variable_name
              setter_method = "#{@association_name}=".to_sym
              @instance.loaded_set.each do |entry|
                entry.send(setter_method, associated_items[entry.key])
              end # @instance.loaded_set.each
            end # if @instance.loaded_set.nil?

            if @pending_members
              pending_members.each do |member|
                @items << member
              end

              pending_members.clear
            end

            return @items
          end # begin
        end # def items

        def inspect
          entries.inspect
        end

        def first
          items.entries.first
        end

        def last
          items.entries.last
        end

        def ==(other)
          (items.size == 1 ? first : items) == other
        end

        def deactivate
          case association.dependency
          when :destroy
            items.entries.each do |member|
              status = member.destroy! unless member.new_record?
              return false unless status
            end
          when :delete
            @instance.database_context.adapter.connection do |db|
              sql = association.to_delete_sql
              parameters = [@instance.key]
              db.create_command(sql).execute_non_query(*parameters)
            end
          when :protect
            unless items.empty?
              raise AssociationProtectedError.new("You cannot delete this model while it has items associated with it.")
            end
          when :nullify
            nullify_association
          else
            nullify_association
          end
        end

        def nullify_association
          @instance.database_context.adapter.connection do |db|
            sql = association.to_disassociate_sql
            parameters = [@instance.key]
            db.create_command(sql).execute_non_query(*parameters)
          end
        end

        private
        def loaded_members
          pending_members + @items
        end

        def pending_members
          @pending_members || @pending_members = Support::TypedSet.new(association.associated_constant)
        end

        def fetch_sets
          finder_options = { association.foreign_key_column.to_sym => @instance.loaded_set.map { |item| item.key } }
          finder_options.merge!(association.finder_options)

          foreign_key_ivar_name = association.foreign_key_column.instance_variable_name

          @instance.database_context.all(
            association.associated_constant,
            finder_options
          ).group_by { |entry| entry.instance_variable_get(foreign_key_ivar_name) }
        end

      end

    end

  end
end
