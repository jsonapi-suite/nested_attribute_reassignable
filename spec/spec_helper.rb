$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'nested_attribute_reassignable'

require 'database_cleaner'
require 'active_record'
require 'pry'
require 'pry-byebug'

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end

ActiveRecord::Migration.verbose = false
ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")

ActiveRecord::Schema.define(:version => 1) do
  create_table :sigils do |t|
    t.string :name
  end

  create_table :families do |t|
    t.belongs_to :sigil
    t.string :name
  end

  create_table :people do |t|
    t.belongs_to :family, index: true
    t.string :name
  end

  create_table :cliques do |t|
    t.string :name
  end

  create_join_table :people, :cliques

  create_table :pets do |t|1
    t.belongs_to :person, index: true
    t.string :name
  end

  create_table :toys do |t|
    t.belongs_to :pet, index: true
    t.string :name
  end

  create_table :offices do |t|
    t.belongs_to :person, index: true
    t.string :name
  end

  create_table :bills do |t|
    t.belongs_to :person, index: true
    t.belongs_to :service, index: true
  end

  create_table :services do |t|
    t.string :name
  end
end

class ApplicationRecord < ActiveRecord::Base
  include NestedAttributeReassignable
  self.abstract_class = true
end

class Person < ApplicationRecord
  has_many :pets
  has_one :office
  belongs_to :family
  has_and_belongs_to_many :cliques

  has_many :bills
  has_many :services, through: :bills, dependent: :destroy

  reassignable_nested_attributes_for :pets
  reassignable_nested_attributes_for :office
  reassignable_nested_attributes_for :family
  reassignable_nested_attributes_for :cliques

  reassignable_nested_attributes_for :services, lookup_key: :name
end

class Clique < ApplicationRecord
  has_and_belongs_to_many :people
end

class SpecialPerson < ApplicationRecord
  self.table_name = 'people'

  has_many    :pets, foreign_key: :person_id
  belongs_to  :family

  reassignable_nested_attributes_for :family, lookup_key: :name
  reassignable_nested_attributes_for :pets, lookup_key: :name
end

class Pet < ApplicationRecord
  belongs_to :person
  has_many :toys

  reassignable_nested_attributes_for :toys
end

class Toy < ApplicationRecord
  belongs_to :pet
end

class Family < ApplicationRecord
  has_many :people
  belongs_to :sigil
  accepts_nested_attributes_for :sigil
end

class Sigil < ApplicationRecord
  has_one :family
end

class Office < ApplicationRecord
  belongs_to :person
end

class Service < ApplicationRecord
end

class Bill < ApplicationRecord
  belongs_to :person
  belongs_to :service
end
