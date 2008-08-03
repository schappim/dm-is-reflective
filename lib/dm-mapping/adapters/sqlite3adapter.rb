
require 'dm-mapping/adapters/abstract_adapter'
require 'dm-mapping/type_map'

module DataMapper
  module Adapters
    class Sqlite3Adapter < DataObjectsAdapter
      module Migration
        def storages
# activerecord-2.1.0/lib/active_record/connection_adapters/sqlite_adapter.rb: 177
          sql = <<-SQL
            SELECT name
            FROM sqlite_master
            WHERE type = 'table' AND NOT name = 'sqlite_sequence'
          SQL
# activerecord-2.1.0/lib/active_record/connection_adapters/sqlite_adapter.rb: 181

          query sql
        end

        def fields table
          query_table(table).map{ |field|
            type, chain = self.class.type_map.
              lookup_primitive(field.type.gsub(/\(\d+\)/, '').upcase)

            # stupid hack
            type = String if type == Class

            attrs = {}
            attrs[:serial] = true if field.pk != 0
            attrs[:nullable] = true if field.notnull != 0 && !attrs[:serial]
            attrs[:default] = field.dflt_value[1..-2] if field.dflt_value

            [field.name, type, attrs.merge(chain.attributes)]
          }
        end
      end
    end
  end
end