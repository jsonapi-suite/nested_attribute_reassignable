# NestedAttributeReassignable

Normal `accepts_nested_attributes_for` works find when all objects being
created are unpersisted. But if the base object is unpersisted and being
associated to pre-existing records, it will blow up:

```ruby
pet = Pet.create!(name: 'Spot')
Person.create(name: 'Joe', pets_attributes: [{ id: pet.id }])
# => ActiveRecord::RecordNotFound: Couldn't find Pet with ID=1 for Person with ID=
```

This gem allows you to assign pre-existing records without error

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'nested_attribute_reassignable'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install nested_attribute_reassignable

## Usage

* Instead of `accepts_nested_attributes_for` use
  `reassignable_nested_attributes_for`.
* You can pass nested IDs **or** nested attributes, not both. If you
  pass both, the attributes will be dropped and the nested record will
not update:

```ruby
pet = Pet.create!(name: 'Spot')
person = Person.create(name: 'Joe', pets_attributes: [{ id: pet.id,
name: 'Elmo' }])
person.reload.pets.first.id == pet.id # => true
person.reload.pets.first.name # => 'Spot', not 'Elmo'
```

`nested_attribute_reassignable` internally calls `accepts_nested_attributes_for`
with `allow_destroy: true` option.

Supports customizing the lookup_key for nested attributes as shown below

```ruby
class Person < ApplicationRecord
  has_many    :pets
  has_many    :bills
  has_many    :services, through: :bills, through: :destroy

  reassignable_nested_attributes_for :services, lookup_key: :name
  reassignable_nested_attributes_for :pets, lookup_key: :name
end

rent    = Service.create!(name: 'Rent')
mobile  = Service.create!(name: 'Mobile')
cat     = Pet.create!(name: 'Cat')

person = Person.create({
  name: 'Joe', 
  services_attributes: [{ id: rent.name }]),
  pets_attributes: [{ id: cat.name }])
}

person.reload.bills.first.service_id == rent.id # => true
person.reload.pets.first.id == cat.id # => true

person.update_attributes({
  pets_attributes: [{ id: cat.name, _destroy: true }])
}

#has_many 
person.reload.pets #=> []
Pet.all #=> [] deletes associated records

#has_many => through
person.update_attributes({
  services_attributes: [{ id: rent.name, _destroy: true }])
}

person.reload.bills #=> []
Service.all #=> [rent, mobile] won't destroy Service, only the join record

person.update_attributes({
  services_attributes: [{ id: rent.name, _delete: true }])
}

person.reload.bills #=> []
Service.all #=> [rent, mobile] won't delete Service, only the join record
```


### _delete

Normal `accepts_nested_attributes_for` accepts a `_destroy` parameter
for destroying the association. This will destroy the underlying record.
If you only want to disassociate the record, you can now use `_delete`.
