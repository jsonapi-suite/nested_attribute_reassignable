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
  create_table :families do |t|
    t.string :name
  end

  create_table :people do |t|
    t.belongs_to :family, index: true
    t.string :name
  end

  create_table :pets do |t|
    t.belongs_to :person, index: true
    t.string :name
  end

  create_table :offices do |t|
    t.belongs_to :person, index: true
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

  reassignable_nested_attributes_for :pets
  reassignable_nested_attributes_for :office
  reassignable_nested_attributes_for :family
end

class Pet < ApplicationRecord
  belongs_to :person
end

class Family < ApplicationRecord
  has_many :people
end

class Office < ApplicationRecord
  belongs_to :person
end
