require 'spec_helper'

if ENV['DEBUG'] == 'true'
  ActiveRecord::Base.logger = Logger.new(STDOUT)
end

describe NestedAttributeReassignable do
  describe "#reassignable_nested_attributes_for" do
    it "should override allow_destroy to be truthy" do
      class Person
        reassignable_nested_attributes_for :pets, allow_destroy: false
      end

      opts = Person.nested_attributes_options[:pets]
      expect(opts[:allow_destroy]).to be_truthy
    end
  end

  describe 'with lookup_key' do
    context 'when has_one' do
      before { Family.create!(name: 'someone') }

      context 'on create' do
        it 'should create associate record' do
          family = Family.create!(name: 'surname')
          p = SpecialPerson.create!(family_attributes: { id: family.name })
          expect(p.family_id).to eq(family.id)
        end
      end

      context 'when no match found' do
        it 'should raise RecordNotFound exception' do
          expect {
            SpecialPerson.create!(family_attributes: { id: 'unknown' })
          }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end

      context 'on update' do
        let!(:instance) { SpecialPerson.create!(family_attributes: { id: family.name }) }
        let!(:family) { Family.create!(name: 'surname') }

        it 'should update associate records' do
          f = Family.create!(name: 'updated')
          instance.update_attributes(family_attributes: { id: 'updated' })
          expect(instance.family_id).to eq(f.id)
        end

        it 'should destroy associate record' do
          instance.update_attributes(family_attributes: { id: family.name })

          instance.update_attributes(family_attributes: { id: family.name, _destroy: true })
          expect(instance.reload.family_id).to be nil
        end

        it 'should delete associate record' do
          instance.update_attributes(family_attributes: { id: family.name })

          instance.update_attributes(family_attributes: { id: family.name, _delete: true })
          expect(instance.reload.family_id).to be nil
        end
      end
    end

    context 'when has_many' do
      let!(:pets) { [Pet.create!(name: 'pet1'), Pet.create!(name: 'pet2')] }

      context 'on create' do
        it 'should create associated records' do
          p = SpecialPerson.create!(pets_attributes: [{ id: pets.first.name }, { id: pets.last.name }])
          expect(p.reload.pets).to eq(pets)
        end
      end

      context 'when no match found' do
        it 'should raise RecordNotFound exception' do
          expect {
            SpecialPerson.create!(pets_attributes: [ { id: 'unknown', _destroy: true}])
          }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end

      context 'on update' do
        let!(:instance) { SpecialPerson.create!(pets_attributes: [{ id: pets.last.name }]) }

        it 'should create new associated records' do
          instance.update_attributes(pets_attributes: [{ id: pets.first.name }])
          expect(instance.reload.pets).to eq(pets)
        end

        context "on _destroy" do
          it 'should remove associated records' do
            instance.update_attributes(pets_attributes: [{ id: pets.first.name }, { id: pets.last.name, _destroy: true}])
            expect(instance.reload.pets).to eq([pets.first])
          end

          it 'should raise exception when matching record not found' do
            expect {
              instance.update_attributes(pets_attributes: [ { id: 'unknown', _destroy: true}])
            }.to raise_error(ActiveRecord::RecordNotFound)
          end
        end

        context "on _delete" do
          it 'should remove associated records' do
            instance.update_attributes(pets_attributes: [{ id: pets.first.name }, { id: pets.last.name, _delete: true}])
            expect(instance.reload.pets).to eq([pets.first])
            expect(Pet.all).to eq(pets)
          end

          it 'should raise exception when matching record not found' do
            expect {
              instance.update_attributes(pets_attributes: [ { id: 'unknown', _delete: true}])
            }.to raise_error(ActiveRecord::RecordNotFound)
          end
        end
      end
    end

    context 'when has_many  :through' do
      let!(:mobile) { Service.create!(name: 'mobile') }
      let!(:rent)   { Service.create!(name: 'rent')   }

      context 'on create' do
        it 'should create associated records' do
          p = Person.create!(services_attributes: [{ id: mobile.name }, { id: rent.name }])
          expect(p.reload.services).to eq([mobile, rent])
        end
      end

      context 'when no match found' do
        it 'should raise RecordNotFound exception' do
          expect {
            Person.create!(services_attributes: [ { id: 'unknown', _destroy: true}])
          }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end

      context 'on update' do
        let!(:instance) { Person.create!(services_attributes: [{ id: rent.name }]) }

        it 'should create new associated records' do
          instance.update_attributes(services_attributes: [{ id: mobile.name }])
          expect(instance.reload.services).to eq([rent, mobile])
        end

        context "on _destroy" do
          xit 'should remove associated records' do
            instance.update_attributes(services_attributes: [{ id: mobile.name }, { id: rent.name, _destroy: true}])

            instance.reload
            expect(instance.subscriptions.count).to eq(1)
            expect(instance.subscriptions[0].bill_id).to eq(mobile.id)
            expect(instance.services).to eq([mobile])
            expect(Service.all).to eq([mobile])
          end

          it 'should raise exception when matching record not found' do
            expect {
              instance.update_attributes(services_attributes: [ { id: 'unknown', _destroy: true}])
            }.to raise_error(ActiveRecord::RecordNotFound)
          end
        end

        context "on _delete" do
          it 'should remove associated records' do
            instance.update_attributes(services_attributes: [{ id: mobile.name }, { id: rent.name, _delete: true}])
            expect(instance.reload.services).to eq([mobile])
          end

          it 'should raise exception when matching record not found' do
            expect {
              instance.update_attributes(services_attributes: [ { id: 'unknown', _delete: true}])
            }.to raise_error(ActiveRecord::RecordNotFound)
          end
        end
      end
    end
  end

  context 'when belongs_to' do
    context 'when passing id only' do
      it 'should assign the id as foreign key' do
        family = Family.create!
        p = Person.create!(family_attributes: { id: family.id })
        expect(p.family_id).to eq(family.id)
      end
    end

    context 'when passing nonexistent id' do
      it 'should raise record not found exception' do
        expect {
          Person.create!(family_attributes: { id: 23 })
        }.to raise_error(ActiveRecord::RecordNotFound)
      end

      context 'and nonexistent_id option is :create' do
        let(:klass) do
          Class.new(Person) do
            reassignable_nested_attributes_for :family,
              nonexistent_id: :create
          end
        end

        it 'should create the record with the given id' do
          expect {
            klass.create!(family_attributes: { id: 23 })
          }.to change { Family.count }.by(1)
          family = Family.last
          expect(family.id).to eq(23)
        end
      end
    end

    context 'when passing attributes without id' do
      it 'should create the association and assign it' do
        p = Person.create!(family_attributes: { name: 'Partridge' })
        expect(p.reload.family.name).to eq('Partridge')
      end

      # No error raised here since it is totally valid to create a new
      # parent record; the old record is still valid and may still have children
      context 'but the record DOES already have a relation' do
        it 'should raise an error' do
          p = Person.create!(family_attributes: { name: 'Partridge' })
          original_family_id = p.family.id
          p.reload
          expect {
            p.update_attributes!(family_attributes: { name: 'Adams' })
          }.to_not raise_error
          p.reload
          expect(p.family_id).to_not eq(original_family_id)
          expect(p.family_id).to_not be_nil
          expect(p.family.name).to eq('Adams')
        end
      end
    end

    context 'when passing id AND attributes' do
      it 'should update the attributes of the given relation' do
        family = Family.create!(name: 'Jetson')
        p = Person.create!(family_attributes: { id: family.id, name: 'Partridge' })
        family = p.reload.family
        expect(family.id).to eq(family.id)
        expect(family.name).to eq('Partridge')
      end

      context 'when the attributes are for another association' do
        it 'should assign the other association and update its attributes' do
          family = Family.create!(name: 'Jetson', sigil: Sigil.create!(name: 'fox'))
          original_family = Family.create!(name: 'old')
          p = Person.create!(family: original_family)

          expect {
            p.update_attributes!(family_attributes: {
              id: family.id,
              name: 'Partridge',
              sigil_attributes: {
                name: 'tree'
              }
            })
          }.to change { p.reload.family }.from(original_family).to(family)
          family = p.reload.family
          expect(family.id).to eq(family.id)
          expect(family.name).to eq('Partridge')
          expect(family.sigil.name).to eq('tree')
        end
      end
    end

    context 'when marking record for destruction' do
      it 'should destroy the relation' do
        family = Family.create!(name: 'Jetson')
        p = Person.create!(family_attributes: { id: family.id })

        expect {
          p.update_attributes(family_attributes: { id: family.id, _destroy: 'true' })
        }.to change { p.reload.family }.from(family).to(nil)
        expect { family.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      context 'via _delete' do
        it 'should remove the relation without destroying the record' do
          family = Family.create!(name: 'Jetson')
          p = Person.create!(family_attributes: { id: family.id })

          expect {
            p.update_attributes(family_attributes: { id: family.id, _delete: 'true' })
          }.to change { p.reload.family }.from(family).to(nil)
          expect { family.reload }.to_not raise_error
        end
      end
    end
  end

  context 'when has_many' do

    context 'when passing only id' do
      it 'should associate the existing objects' do
        pets = [Pet.create!, Pet.create!]
        p = Person.create!(pets_attributes: [{ id: pets.first.id }, { id: pets.last.id }])
        expect(p.reload.pets).to eq(pets)
      end

      it 'should handle multiple updates on parent' do
        pets = [Pet.create!, Pet.create!]
        p = Person.create!
        p.update_attributes(pets_attributes: [{ id: pets.first.id }])
        p.update_attributes(pets_attributes: [{ id: pets.last.id }])
        expect(p.reload.pets).to eq(pets)
      end
    end

    context 'when passing nonexistent id' do
      it 'should raise record not found exception' do
        pets = [Pet.create!, Pet.create!]
        expect {
          Person.create!(pets_attributes: [{ id: 23 }, { id: pets.last.id }])
        }.to raise_error(ActiveRecord::RecordNotFound)
      end

      context 'and nonexistent_id option is :create' do
        let(:klass) do
          Class.new(Person) do
            reassignable_nested_attributes_for :pets,
              nonexistent_id: :create
          end
        end

        it 'creates the record with the corresponding id' do
          pets = [Pet.create!, Pet.create!]
          expect {
            klass.create!(pets_attributes: [{ id: 23 }, { id: pets.last.id }])
          }.to change { Pet.count }.by(1)
          person = Person.last
          expect(person.pets.length).to eq(2)
          expect(person.pets[0].id).to eq(pets.last.id)
          expect(person.pets[1].id).to eq(23)
        end
      end
    end

    context 'when updating an existing recordset' do
      let(:pet) { Pet.create!(name: 'doggy') }
      let(:pet_to_delete) { Pet.create!(name: 'delme') }
      let(:pet_to_destroy) { Pet.create!(name: 'destroyme') }
      let(:pet_to_associate) { Pet.create!(name: 'associateme') }

      let!(:person) do
        person = Person.new(name: 'joe')
        person.pets = [pet, pet_to_delete, pet_to_destroy]
        person.save!
        person.reload
        person
      end

      # This is so the #update action can sideload (include) only the
      # records that were sent as part of the update's nested relations
      it 'should memoize the recordset as only the records updated, excluding deletions' do
        expect(person.pets.length).to eq(3)
        person.reload
        person.update_attributes! pets_attributes: [
          { name: 'catty' },
          { id: pet_to_associate.id },
          { id: pet_to_delete.id, _delete: true },
          { id: pet_to_destroy.id, _destroy: true },
        ]
        expect(person.pets.length).to eq(2)
        expect(person.pets[0].name).to eq('associateme')
        expect(person.pets[1].name).to eq('catty')
        person.reload
        expect(person.pets.length).to eq(3)
        expect(person.pets[0].name).to eq('doggy')
        expect(person.pets[1].name).to eq('associateme')
        expect(person.pets[2].name).to eq('catty')
      end
    end

    # Don't require the API request to send 10,000 comment ids, just the new comment ids
    context 'when passing a subset of all ids' do
      it 'should append to the association array, not replace it' do
        person = Person.create!(pets: [Pet.create!(name: 'Spot')])
        expect(person.pets.map(&:name)).to match_array(%w(Spot))
        pet2 = Pet.create!(name: 'lassie')
        person.update_attributes!(pets_attributes: [{ id: pet2.id }])
        expect(person.reload.pets.map(&:name)).to match_array(%w(Spot lassie))
      end
    end

    context 'when passing id and attributes in the same record' do
      it 'should update the associated record' do
        pet = Pet.create!(name: 'original')
        p = Person.create!(pets_attributes: [{ id: pet.id, name: 'newname' }])
        created = p.reload.pets.first
        expect(created.id).to eq(pet.id)
        expect(created.name).to eq('newname')
      end

      context 'and the attributes are for another association' do
        it 'should add the record to the association array and update its properties' do
          pet    = Pet.create!(name: 'original')
          person = Person.create!(name: 'newname', pets: [pet])
          pet2   = Pet.create!(name: 'newpet')

          person.update_attributes! pets_attributes: [
            {
              id: pet2.id,
              name: 'newname',
              toys_attributes: [
                { name: 'ball' }
              ]
            }
          ]
          person.reload

          expect(person.pets.length).to eq(2)
          created = person.pets.last
          expect(created.id).to eq(pet2.id)
          expect(created.name).to eq('newname')
          expect(created.toys.first.name).to eq('ball')
        end
      end
    end

    context 'when passing id in one record, attributes in another' do
      it 'should associate the id record, create the other' do
        existing = Pet.create!(name: 'original')
        p = Person.create!(pets_attributes: [{ id: existing.id }, { name: 'spot' }])
        created = p.reload.pets
        expect(created.map(&:id)).to include(existing.id)
        expect(created.map(&:name)).to match_array(%w(original spot))
      end
    end

    context 'when marking for destruction' do
      it 'should destroy the relation' do
        spot = Pet.create!(name: 'spot')
        delme = Pet.create!(name: 'delme')
        p = Person.create(pets: [spot, delme])
        p.update_attributes!(pets_attributes: [{ id: delme.id, _destroy: 'true' }])
        expect(p.reload.pets.map(&:name)).to match_array(%(spot))
        expect { delme.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      context 'via _delete' do
        it 'should remove the relation without destroying the object' do
          spot = Pet.create!(name: 'spot')
          delme = Pet.create!(name: 'delme')
          p = Person.create(pets: [spot, delme])
          p.update_attributes!(pets_attributes: [{ id: delme.id, _delete: 'true' }])
          expect(p.reload.pets.map(&:name)).to match_array(%(spot))
          expect { delme.reload }.to_not raise_error
        end
      end
    end
  end

  context 'when has_one' do
    it 'should associate the existing objects' do
      office = Office.create!
      p = Person.create!(office_attributes: { id: office.id })
      expect(p.reload.office).to eq(office)
    end

    context 'but the record DOES already have a relation' do
      it 'should raise an error' do
        p = Person.create!(office_attributes: { name: 'staples' })
        expect {
          p.update_attributes!(office_attributes: { name: 'carfax' })
        }.to raise_error(NestedAttributeReassignable::RelationExists)
      end
    end

    context 'when marking for destruction' do
      it 'should destroy the relation' do
        office = Office.create!
        p = Person.create!(office_attributes: { id: office.id })

        expect {
          p.update_attributes(office_attributes: { id: office.id, _destroy: true })
        }.to change { p.reload.office }.from(office).to(nil)
        expect { office.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      context 'and it is a _delete' do
        it 'should remove the relation without destroying the object' do
          office = Office.create!
          p = Person.create!(office_attributes: { id: office.id })

          expect {
            p.update_attributes(office_attributes: { id: office.id, _delete: true })
          }.to change { p.reload.office }.from(office).to(nil)
          expect { office.reload }.to_not raise_error
        end
      end
    end
  end

  context 'when has_and_belongs_to_many' do
    let!(:math) { Clique.create!(name: 'math club') }
    let!(:chess) { Clique.create!(name: 'chess club') }

    context 'on create' do
      it 'should create associations' do
        p = Person.create!(cliques_attributes: [{ id: math.id }, { id: chess.id }])
        expect(p.reload.cliques).to eq([math, chess])
      end
    end

    context 'on update' do
      let!(:instance) { Person.create!(cliques_attributes: [{ id: math.id }]) }

      it 'should add records to the association' do
        instance.update_attributes(cliques_attributes: [{ id: chess.id }])
        expect(instance.reload.cliques).to eq([math, chess])
      end

      it 'should update the associated record' do
        instance.update(cliques_attributes: [{ id: math.id, name: 'math clan' }])
        expect(math.reload.name).to eq('math clan')
      end

      it 'should not create duplicate join-table records' do
        expect(instance.cliques.count).to eq(1)
        instance.update(cliques_attributes: [{ id: math.id, name: 'math clan' }])
        expect(instance.cliques.count).to eq(1)
      end
    end
  end
end
