module ActiveRecord
  module ConnectionAdapters
    module Fb
      module DatabaseStatements
        # Returns an array of record hashes with the column names as keys and
        # column values as values.
        # def select_all(sql, name = nil, format = :hash) # :nodoc:
        #   translate(sql) do |sql, args|
        #     log(sql, args, name) do
        #       @connection.query(format, sql, *args)
        #     end
        #   end
        # end
        # Returns an array of record hashes with the column names as keys and
        # column values as values.
        def select_all(arel, name = nil, binds = [])
          add_column_types(select(to_sql(arel, binds), name, binds))
        end

        # Returns an array of arrays containing the field values.
        # Order is the same as that returned by +columns+.
        def select_rows(sql, name = nil)
          log(sql, name) do
            @connection.query(:array, sql)
          end
        end

        # Executes the SQL statement in the context of this connection.
        def execute(sql, name = nil, skip_logging = false)
          translate(sql) do |sql, args|
            if (name == :skip_logging) or skip_logging
              @connection.execute(sql, *args)
            else
              log(sql, args, name) do
                @connection.execute(sql, *args)
              end
            end
          end
        end

        # Executes +sql+ statement in the context of this connection using
        # +binds+ as the bind substitutes. +name+ is logged along with
        # the executed +sql+ statement.
        def exec_query(sql, name = 'SQL', binds = [])
          translate(sql) do |sql, args|
            unless binds.empty?
              args = binds.map { |col, val| type_cast(val, col) } + args
            end
            log(expand(sql, args), name) do
              result, rows = @connection.execute(sql, *args) { |cursor| [cursor.fields, cursor.fetchall] }
              if result.respond_to?(:map)
                cols = result.map { |col| col.name }
                ActiveRecord::Result.new(cols, rows)
              else
                result
              end
            end
          end
        end

        def explain(arel, binds = [])
          to_sql(arel, binds)
        end

        # Returns the last auto-generated ID from the affected table.
        def insert(arel, name = nil, pk = nil, id_value = nil, sequence_name = nil, binds = [])
          sql, binds = sql_for_insert(to_sql(arel, binds), pk, id_value, sequence_name, binds)
          value      = exec_insert(sql, name, binds)
          id_value
        end

        # Executes the update statement and returns the number of rows affected.
        # alias_method :update, :execute
        # def update(sql, name = nil)
        #   update_sql(sql, name)
        # end

        # Executes the delete statement and returns the number of rows affected.
        # alias_method :delete, :execute
        # def delete(sql, name = nil)
        #   delete_sql(sql, name)
        # end

        # Checks whether there is currently no transaction active. This is done
        # by querying the database driver, and does not use the transaction
        # house-keeping information recorded by #increment_open_transactions and
        # friends.
        #
        # Returns true if there is no transaction active, false if there is a
        # transaction active, and nil if this information is unknown.
        def outside_transaction?
          !@connection.transaction_started
        end

        # Begins the transaction (and turns off auto-committing).
        def begin_db_transaction
          @transaction = @connection.transaction('READ COMMITTED')
        end

        # Commits the transaction (and turns on auto-committing).
        def commit_db_transaction
          @transaction = @connection.commit
        end

        # Rolls back the transaction (and turns on auto-committing). Must be
        # done if the transaction block raises an exception or returns false.
        def rollback_db_transaction
          @transaction = @connection.rollback
        end

        # Appends +LIMIT+ and +OFFSET+ options to an SQL statement, or some SQL
        # fragment that has the same semantics as LIMIT and OFFSET.
        #
        # +options+ must be a Hash which contains a +:limit+ option
        # and an +:offset+ option.
        #
        # This method *modifies* the +sql+ parameter.
        #
        # ===== Examples
        #  add_limit_offset!('SELECT * FROM suppliers', {:limit => 10, :offset => 50})
        # generates
        #  SELECT * FROM suppliers LIMIT 10 OFFSET 50
        def add_limit_offset!(sql, options) # :nodoc:
          if limit = options[:limit]
            if offset = options[:offset]
              sql << " ROWS #{offset.to_i + 1} TO #{offset.to_i + limit.to_i}"
            else
              sql << " ROWS #{limit.to_i}"
            end
          end
          sql
        end

        def default_sequence_name(table_name, column = nil)
          "#{table_name.to_s.tr('-', '_')[0, table_name_length - 4]}_seq"
        end

        # Set the sequence to the max value of the table's column.
        def reset_sequence!(table, column, sequence = nil)
          max_id = select_value("select max(#{column}) from #{table}")
          execute("alter sequence #{default_sequence_name(table, column)} restart with #{max_id}")
        end

        def next_sequence_value(sequence_name)
          select_one("SELECT NEXT VALUE FOR #{sequence_name} FROM RDB$DATABASE").values.first
        end

        # Inserts the given fixture into the table. Overridden in adapters that require
        # something beyond a simple insert (eg. Oracle).
        # def insert_fixture(fixture, table_name)
        #   execute "INSERT INTO #{quote_table_name(table_name)} (#{fixture.key_list}) VALUES (#{fixture.value_list})", 'Fixture Insert'
        # end

        # def empty_insert_statement_value
        #   "VALUES(DEFAULT)"
        # end

        # def case_sensitive_equality_operator
        #   "="
        # end

      protected
        # add column_types method returns empty hash, requred for rails 4 compatibility
        def add_column_types obj
          FbArray.new(obj)
        end

        # Returns an array of record hashes with the column names as keys and
        # column values as values.
        def select(sql, name = nil, binds = [])
          translate(sql) do |sql, args|
            unless binds.empty?
              args = binds.map { |col, val| type_cast(val, col) } + args
            end
            log(expand(sql, args), name) do
              @connection.query(:hash, sql, *args)
            end
          end
        end
      end
    end
  end
end
