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

### _delete

Normal `accepts_nested_attributes_for` accepts a `_destroy` parameter
for destroying the association. This will destroy the underlying record.
If you only want to disassociate the record, you can now use `_delete`.
