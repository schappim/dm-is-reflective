
module DataMapper
  module Adapters
    class AbstractAdapter
      module Migration
        # returns all tables' name in the repository.
        #  e.g.
        #       ['comments', 'users']
        def storages
          raise NotImplementedError
        end

        # returns all fields, with format [[name, type, attrs]]
        #  e.g.
        #       [['created_at',  DateTime, {}],
        #        ['email',       String,   {:default => 'nospam@nospam.tw'}],
        #        ['id',          Integer,  {:serial => true}],
        #        ['salt_first',  String,   {}],
        #        ['salt_second', String,   {}]]
        def fields storage
          dmm_query_storage(storage).map{ |field|
            type, chain = self.class.type_map.
              lookup_primitive(dmm_primitive(field))

            [dmm_field_name(field), type, dmm_attributes(field)]
          }
        end

        # returns a hash with storage names in keys and
        # corresponded fields in values. e.g.
        #   {'users' => [['id',          Integer,  {:serial => true}],
        #                ['email',       String,   {:default => 'nospam@nospam.tw'}],
        #                ['created_at',  DateTime, {}],
        #                ['salt_first',  String,   {}],
        #                ['salt_second', String,   {}]]}
        # see Migration#storages and Migration#fields for detail
        def storages_and_fields
          storages.inject({}){ |result, storage|
            result[storage] = fields(storage)
            result
          }
        end

        # automaticly generate model class(es) and mapping
        # all fields with mapping /.*/ for you.
        #  e.g.
        #       dm.auto_genclass!
        #       # => [DataMapper::Mapping::User,
        #       #     DataMapper::Mapping::SchemaInfo,
        #       #     DataMapper::Mapping::Session]
        #
        # you can change the scope of generated models:
        #  e.g.
        #       dm.auto_genclass! :scope => Object
        #       # => [User, SchemaInfo, Session]
        #
        # you can generate classes for tables you specified only:
        #  e.g.
        #       dm.auto_genclass! :scope => Object, :storages => /^phpbb_/
        #       # => [PhpbbUser, PhpbbPost, PhpbbConfig]
        #
        # you can generate classes with String too:
        #  e.g.
        #       dm.auto_genclass! :storages => ['users', 'config'], :scope => Object
        #       # => [User, Config]
        #
        # you can generate a class only:
        #  e.g.
        #       dm.auto_genclass! :storages => 'users'
        #       # => [DataMapper::Mapping::User]
        def auto_genclass! opts = {}
          opts[:scope] ||= DataMapper::Mapping
          opts[:storages] ||= /.*/
          opts[:storages] = [opts[:storages]].flatten

          storages_and_fields.map{ |storage, fields|

            mapped = opts[:storages].each{ |target|
              case target
                when Regexp;
                  break storage if storage =~ target

                when Symbol, String;
                  break storage if storage == target.to_s

                else
                  raise ArgumentError.new("invalid argument: #{target.inspect}")
              end
            }

            dmm_genclass mapped, fields, opts[:scope] if mapped.kind_of?(String)
          }.compact
        end

        private
        def dmm_query_storage
          raise NotImplementError.new("#{self.class}#fields is not implemented.")
        end

        def dmm_genclass storage, fields, scope
          require 'extlib'
          model = Class.new
          model.__send__ :include, DataMapper::Resource
          model.storage_names[:default] = storage
          model.__send__ :mapping, /.*/
          scope.const_set(Extlib::Inflection.classify(storage), model)
        end
      end
    end
  end
end
