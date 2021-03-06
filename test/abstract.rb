
require 'dm-core'
require 'dm-is-reflective'

module Abstract
  def setup_data_mapper
    raise 'please provide a clean database because it is a destructive test!!'
  end

  AttrCommon   = {:nullable => true}
  AttrCommonPK = {:serial => true, :key => true, :nullable => false}
  AttrText     = {:length => 65535}.merge(AttrCommon)

  def user_fields
    [[:created_at, DateTime, AttrCommon],
     [:id,         DataMapper::Types::Serial,  AttrCommonPK],
     [:login,      String,   {:length => 70}.merge(AttrCommon)],
     [:sig,        DataMapper::Types::Text, AttrText]]
  end

  def comment_fields
    [[:body,    DataMapper::Types::Text,    AttrText],
     [:id,      DataMapper::Types::Serial,  AttrCommonPK],
     [:title,   String,   {:length => 50, :default => 'default title'}.
                            merge(AttrCommon)],
     [:user_id, Integer,  AttrCommon]]
  end

  # there's differences between adapters
  def super_user_fields
    case self
      when MysqlTest # Mysql couldn't tell it's boolean or tinyint
        [[:bool, Integer, AttrCommon],
         [:id,   DataMapper::Types::Serial, AttrCommonPK]]

      else
        [[:bool, DataMapper::Types::Boolean, AttrCommon],
         [:id,   DataMapper::Types::Serial,  AttrCommonPK]]

    end
  end

  class User
    include DataMapper::Resource
    has n, :comments

    property :id,         Serial
    property :login,      String, :length => 70
    property :sig,        Text
    property :created_at, DateTime

    is :reflective
  end

  class SuperUser
    include DataMapper::Resource
    property :id, Serial
    property :bool, Boolean

    is :reflective
  end

  class Comment
    include DataMapper::Resource
    belongs_to :user, :nullable => true

    property :id,    Serial
    property :title, String,  :length => 50, :default => 'default title'
    property :body,  Text

    is :reflective
  end

  class Model; end

  Tables = ['abstract_comments', 'abstract_super_users', 'abstract_users']

  def sort_fields fields
    fields.sort_by{ |field|
      field.first.to_s
    }
  end

  def create_fake_model
    model = Model.dup.send(:include, DataMapper::Resource)
    model.is :reflective
    [ model, setup_data_mapper ]
  end

  attr_reader :dm
  def setup
    @dm = setup_data_mapper
    # this is significant faster than DataMapper.auto_migrate!
    User.auto_migrate!
    Comment.auto_migrate!
    SuperUser.auto_migrate!
  end

  def new_scope
    self.class.const_set("Scope#{object_id.object_id}", Module.new)
  end

  def test_storages
    assert_equal Tables, dm.storages.sort
    assert_equal comment_fields, sort_fields(dm.fields('abstract_comments'))
  end

  def test_create_comment
    Comment.create(:title => 'XD')
    assert_equal 1, Comment.first.id
    assert_equal 'XD', Comment.first.title
  end

  def test_create_user
    now = Time.now
    User.create(:created_at => now)
    assert_equal 1, User.first.id
    assert_equal now.asctime, User.first.created_at.asctime

    return now
  end

  def test_reflect_all
    test_create_comment # for fixtures
    model, local_dm = create_fake_model
    model.storage_names[:default] = 'abstract_comments'

    assert_equal Tables, local_dm.storages.sort
    assert_equal 'abstract_comments', model.storage_name

    model.send :reflect
    assert_equal 1, model.all.size
    assert_equal comment_fields, sort_fields(model.fields)

    assert_equal 'XD', model.first.title
    assert_equal 1, model.first.id
  end

  def test_reflect_and_create
    model, local_dm = create_fake_model
    model.storage_names[:default] = 'abstract_comments'
    model.send :reflect

    model.create(:title => 'orz')
    assert_equal 'orz', model.first.title
    assert_equal 1, model.first.id

    model.create
    assert_equal 'default title', model.get(2).title
  end

  def test_storages_and_fields
    assert_equal user_fields, sort_fields(dm.fields('abstract_users'))
    assert_equal( {'abstract_users' => user_fields,
                   'abstract_comments' => comment_fields,
                   'abstract_super_users' => super_user_fields},
                  dm.storages_and_fields.inject({}){ |r, i|
                    key, value = i
                    r[key] = value.sort_by{ |v| v.first.to_s }
                    r
                  } )
  end

  def test_reflect_type
    model, local_dm = create_fake_model
    model.storage_names[:default] = 'abstract_comments'

    model.send :reflect, DataMapper::Types::Serial
    assert_equal ['id'], model.properties.map(&:name).map(&:to_s).sort

    model.send :reflect, Integer
    assert_equal ['id', 'user_id'], model.properties.map(&:name).map(&:to_s).sort
  end

  def test_reflect_multiple
    model, local_dm = create_fake_model
    model.storage_names[:default] = 'abstract_users'
    model.send :reflect, :login, DataMapper::Types::Serial

    assert_equal ['id', 'login'], model.properties.map(&:name).map(&:to_s).sort
  end

  def test_reflect_regexp
    model, local_dm = create_fake_model
    model.storage_names[:default] = 'abstract_comments'
    model.send :reflect, /id$/

    assert_equal ['id', 'user_id'], model.properties.map(&:name).map(&:to_s).sort
  end

  def test_invalid_argument
    assert_raises(ArgumentError){
      User.send :reflect, 29
    }
  end

  def test_auto_genclasses
    scope = new_scope
    assert_equal ["#{scope == Object ? '' : "#{scope}::"}AbstractComment",
                  "#{scope}::AbstractSuperUser",
                  "#{scope}::AbstractUser"],
                 dm.auto_genclass!(:scope => scope).map(&:to_s).sort

    comment = scope.const_get('AbstractComment')

    assert_equal comment_fields, sort_fields(comment.fields)

    test_create_comment

    assert_equal 'XD', comment.first.title
    comment.create(:title => 'orz', :body => 'dm-reflect')
    assert_equal 'dm-reflect', comment.get(2).body
  end

  def test_auto_genclass
    scope = new_scope
    assert_equal ["#{scope}::AbstractUser"],
                 dm.auto_genclass!(:scope => scope,
                                   :storages => 'abstract_users').map(&:to_s)

    user = scope.const_get('AbstractUser')
    assert_equal user_fields, sort_fields(user.fields)

    now = test_create_user

    assert_equal now.asctime, user.first.created_at.asctime
    user.create(:login => 'godfat')
    assert_equal 'godfat', user.get(2).login
  end

  def test_auto_genclass_with_regexp
    scope = new_scope
    assert_equal ["#{scope}::AbstractSuperUser", "#{scope}::AbstractUser"],
                 dm.auto_genclass!(:scope => scope,
                                   :storages => /_users$/).map(&:to_s).sort

    user = scope.const_get('AbstractSuperUser')
    assert_equal sort_fields(SuperUser.fields), sort_fields(user.fields)
  end

  def test_reflect_return_value
    model, local_dm = create_fake_model
    model.storage_names[:default] = 'abstract_comments'
    mapped = model.send :reflect, /.*/

    assert_equal model.properties.map(&:object_id).sort, mapped.map(&:object_id).sort
  end

end
