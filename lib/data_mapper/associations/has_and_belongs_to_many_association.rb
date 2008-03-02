module DataMapper
  module Associations

    class HasAndBelongsToManyAssociation

      attr_reader :adapter

      def initialize(klass, association_name, options)
        @adapter = repository.adapter
        @key_table = adapter.table(klass)
        @self_referential = (association_name.to_s == @key_table.name)
        @association_name = association_name.to_sym
        @options = options

        define_accessor(klass)
      end

      # def key_table
      #   @key_table
      # end

      def name
        @association_name
      end

      def dependency
        @options[:dependent]
      end

      def foreign_name
        @foreign_name || (@foreign_name = (@options[:foreign_name] || @key_table.name).to_sym)
      end

      def self_referential?
        @self_referential
      end

      def constant
        @associated_class || @associated_class = begin

          if @options.has_key?(:class) || @options.has_key?(:class_name)
            associated_class_name = (@options[:class] || @options[:class_name])
            if associated_class_name.kind_of?(String)
              Kernel.const_get(Inflector.classify(associated_class_name))
            else
              associated_class_name
            end
          else
            Kernel.const_get(Inflector.classify(@association_name))
          end

        end
      end

      def activate!(force = false)
        join_columns.each {|column| column unless join_table.mapped_column_exists?(column.name)}
        join_table.create!(force)
      end

      def associated_columns
        associated_table.columns.reject { |column| column.lazy? } + join_columns
      end

      def join_columns
        [ left_foreign_key, right_foreign_key ]
      end

      def associated_table
        @associated_table || (@associated_table = adapter.table(constant))
      end

      def join_table
        @join_table || @join_table = begin
          join_table_name = @options[:join_table] ||
            [ @key_table.name.to_s, repository.schema[constant].name.to_s ].sort.join('_')

          adapter.table(join_table_name)
        end
      end

      def left_foreign_key
        @left_foreign_key || @left_foreign_key = begin
          join_table.add_column(
            (@options[:left_foreign_key] || @key_table.default_foreign_key),
            :integer, :nullable => true, :key => true)
        end
      end

      def right_foreign_key
        if self_referential?
          @options[:right_foreign_key] ||= ["related_", associated_table.default_foreign_key].to_s
        end

        @right_foreign_key || @right_foreign_key = begin
          join_table.add_column(
            (@options[:right_foreign_key] || associated_table.default_foreign_key),
            :integer, :nullable => true, :key => true)
        end
      end

      def to_sql
        <<-EOS.compress_lines
          JOIN #{join_table.to_sql} ON
            #{left_foreign_key.to_sql(true)} = #{@key_table.key.to_sql(true)}
          JOIN #{associated_table.to_sql} ON
            #{associated_table.key.to_sql(true)} = #{right_foreign_key.to_sql(true)}
        EOS
      end

      def to_shallow_sql
        if self_referential?
          <<-EOS.compress_lines
            JOIN #{join_table.to_sql} ON
              #{right_foreign_key.to_sql(true)} = #{@key_table.key.to_sql(true)}
          EOS
        else
        <<-EOS.compress_lines
          JOIN #{join_table.to_sql} ON
            #{left_foreign_key.to_sql(true)} = #{@key_table.key.to_sql(true)}
        EOS
        end
      end

      def to_insert_sql
        <<-EOS.compress_lines
          INSERT INTO #{join_table.to_sql}
          (#{left_foreign_key.to_sql}, #{right_foreign_key.to_sql})
          VALUES
        EOS
      end

      def to_delete_sql
        <<-EOS.compress_lines
          DELETE FROM #{join_table.to_sql}
          WHERE #{left_foreign_key.to_sql} = ?
        EOS
      end

      def to_delete_set_sql
        <<-EOS.compress_lines
          DELETE FROM #{join_table.to_sql}
          WHERE #{left_foreign_key.to_sql} IN ?
            OR #{right_foreign_key.to_sql} IN ?
        EOS
      end

      def to_delete_members_sql
        <<-EOS.compress_lines
          DELETE FROM #{associated_table.to_sql}
          WHERE #{associated_table.key.to_sql} IN ?
        EOS
      end

      def to_delete_member_sql
        <<-EOS
          DELETE FROM #{join_table.to_sql}
          WHERE #{left_foreign_key.to_sql} = ?
            AND #{right_foreign_key.to_sql} = ?
        EOS
      end

      def to_disassociate_sql
        <<-EOS
          UPDATE #{join_table.to_sql}
          SET #{left_foreign_key.to_sql} = NULL
          WHERE #{left_foreign_key.to_sql} = ?
        EOS
      end

      # Define the association instance method (i.e. Project#tasks)
      def define_accessor(klass)
        klass.class_eval <<-EOS
          def #{@association_name}
            @#{@association_name} || (@#{@association_name} = HasAndBelongsToManyAssociation::Set.new(self, #{@association_name.inspect}))
          end

          def #{@association_name}=(value)
            #{@association_name}.set(value)
          end

          private
          def #{@association_name}_keys=(value)
            #{@association_name}.clear

            associated_constant = #{@association_name}.association.constant
            associated_table = #{@association_name}.association.associated_table
            associated_constant.all(associated_table.key => [*value]).each do |entry|
              #{@association_name} << entry
            end
          end
        EOS
      end

      class Set < Associations::Reference

        include Enumerable

        def each
          entries.each { |item| yield item }
        end

        def size
          entries.size
        end
        alias length size

        def count
          entries.size
        end

        def [](key)
          entries[key]
        end

        def empty?
          entries.empty?
        end

        def dirty?(cleared = ::Set.new)
          return false unless @entries
          @entries.any? {|item| cleared.include?(item) || item.dirty?(cleared) } || @associated_keys != @entries.map { |entry| entry.keys }
        end

        def validate_recursively(event, cleared)
          @entries.blank? || @entries.all? { |item| cleared.include?(item) || item.validate_recursively(event, cleared) }
        end

        def save_without_validation(database_context, cleared)
          unless @entries.nil?

            if dirty?(cleared)
              adapter = @instance.database_context.adapter

              adapter.connection do |db|
                command = db.create_command(association.to_delete_sql)
                command.execute_non_query(@instance.key)
              end

              unless @entries.empty?
                if adapter.batch_insertable?
                  sql = association.to_insert_sql
                  values = []
                  keys = []

                  @entries.each do |member|
                    adapter.save_without_validation(database_context, member, cleared)
                    values << "(?, ?)"
                    keys << @instance.key << member.key
                  end

                  adapter.connection do |db|
                    command = db.create_command(sql << ' ' << values.join(', '))
                    command.execute_non_query(*keys)
                  end

                else # adapter doesn't support batch inserts...
                  @entries.each do |member|
                    adapter.save_without_validation(database_context, member, cleared)
                  end

                  # Just to keep the same flow as the batch-insert mode.
                  @entries.each do |member|
                    adapter.connection do |db|
                      command = db.create_command("#{association.to_insert_sql} (?, ?)")
                      command.execute_non_query(@instance.key, member.key)
                    end
                  end
                end # if adapter.batch_insertable?
              end # unless @entries.empty?
            end # if dirty?
          end
        end

        def <<(member)
          return nil unless member

          if member.is_a?(Enumerable)
            member.each { |entry| entries << entry }
          else
            entries << member
          end
        end

        def clear
          @entries = Support::TypedSet.new(association.constant)
        end

        def reload!
          @entries = nil
        end

        def delete(member)
          if found_member = entries.detect { |entry| entry == member }
            entries.delete?(found_member)
            @instance.database_context.adapter.connection do |db|
              command = db.create_command(association.to_delete_member_sql)
              command.execute_non_query(@instance.key, member.key)
            end
            member
          else
            nil
          end
        end

        def method_missing(symbol, *args, &block)
          if entries.respond_to?(symbol)
            entries.send(symbol, *args, &block)
          elsif association.associated_table.associations.any? { |assoc| assoc.name == symbol }
            results = []
            each do |item|
              unless (val = item.send(symbol)).blank?
                results << (val.is_a?(Enumerable) ? val.entries : val)
              end
            end
            results.flatten
          else
            super
          end
        end

        def entries
          @entries || @entries = begin

            if @instance.loaded_set.nil?
              Support::TypedSet.new(association.constant)
            else

              associated_items = Hash.new { |h,k| h[k] = [] }
              left_key_index = nil
              association_constant = association.constant
              left_foreign_key = association.left_foreign_key

              matcher = lambda do |instance,columns,row|

                # Locate the column for the left-key.
                unless left_key_index
                  columns.each_with_index do |column, index|
                    if column.name == association.left_foreign_key.name
                      left_key_index = index
                      break
                    end
                  end
                end

                if instance.kind_of?(association_constant)
                  associated_items[left_foreign_key.type_cast_value(row[left_key_index])] << instance
                end
              end

              @instance.database_context.all(association.constant,
                left_foreign_key => @instance.loaded_set.map(&:key),
                :shallow_include => association.foreign_name,
                :intercept_load => matcher
              )

              # do stsuff with associated_items hash.
              setter_method = "#{@association_name}=".to_sym

              @instance.loaded_set.each do |entry|
                entry.send(setter_method, associated_items[entry.key])
              end # @instance.loaded_set.each

              @entries
            end
          end
        end

        def set(results)
          if results.is_a?(Support::TypedSet)
            @entries = results
          else
            @entries = Support::TypedSet.new(association.constant)
            [*results].each { |item| @entries << item }
          end
          @associated_keys = @entries.map { |entry| entry.key }
          return @entries
        end

        def inspect
          entries.inspect
        end

        def first
          entries.entries.first
        end

        def last
          entries.entries.last
        end

        def deactivate
          case association.dependency
          when :destroy
            entries.each do |member|
              member.destroy! unless member.new_record?
            end
          when :delete
            delete_association
          when :protect
            unless entries.empty?
              raise AssociationProtectedError.new("You cannot delete this model while it has items associated with it.")
            end
          when :nullify
            nullify_association
          else
            nullify_association
          end
        end

        def delete_association
          @instance.database_context.adapter.connection do |db|
            associated_keys = entries.collect do |item|
              item.key unless item.new_record?
            end.compact
            parameters = [@instance.key] + associated_keys

            sql = association.to_delete_set_sql
            db.create_command(sql).execute_non_query(*[parameters, parameters])

            sql = association.to_delete_members_sql
            db.create_command(sql).execute_non_query(associated_keys)
          end
        end

        def nullify_association
          @instance.database_context.adapter.connection do |db|
            sql = association.to_delete_sql
            parameters = [@instance.key]
            db.create_command(sql).execute_non_query(*parameters)
          end
        end
      end

    end # class HasAndBelongsToManyAssociation

  end # module Associations
end # module DataMapper
