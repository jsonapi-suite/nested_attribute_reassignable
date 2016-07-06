require 'spec_helper'

#ActiveRecord::Base.logger = Logger.new(STDOUT)

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
  end

  context 'when belongs_to' do
    context 'when passing id only' do
      it 'should assign the id as foreign key' do
        family = Family.create!
        p = Person.create!(family_attributes: { id: family.id })
        expect(p.family_id).to eq(family.id)
      end
    end

    context 'when passing non existing id' do
      it 'should raise record not found exception' do
        expect {  
          Person.create!(family_attributes: { id: 23 })
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when passing attributes without id' do
      it 'should create the association and assign it' do
        p = Person.create!(family_attributes: { name: 'Partridge' })
        expect(p.reload.family.name).to eq('Partridge')
      end
    end

    context 'when passing id AND attributes' do
      it 'should drop the attributes, not update the relation' do
        family = Family.create!(name: 'Jetson')
        p = Person.create!(family_attributes: { id: family.id, name: 'Partridge' })
        family = p.reload.family
        expect(family.id).to eq(family.id)
        expect(family.name).to eq('Jetson')
      end

      context 'when the attributes are for another association' do
        it 'should still assign that association' do
          family = Family.create!(name: 'Jetson')
          p = Person.create!(family_attributes: {
            id: family.id,
            name: 'Partridge',
            sigil_attributes: {
            name: 'tree'
          }
          })
          family = p.reload.family
          expect(family.id).to eq(family.id)
          expect(family.name).to eq('Jetson')
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

    context 'when passing non existent id' do
      it 'should raise record not found exception' do
        pets = [Pet.create!, Pet.create!]
        expect { 
          Person.create!(pets_attributes: [{ id: 23 }, { id: pets.last.id }])
        }.to raise_error(ActiveRecord::RecordNotFound)
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
      it 'should associate, not update the record' do
        pet = Pet.create!(name: 'original')
        p = Person.create!(pets_attributes: [{ id: pet.id, name: 'newname' }])
        created = p.reload.pets.first
        expect(created.id).to eq(pet.id)
        expect(created.name).to eq('original')
      end

      context 'and the attributes are for another association' do
        it 'should still handle the other association' do
          pet = Pet.create!(name: 'original')
          p = Person.create!(pets_attributes: [
                             {
            id: pet.id,
            name: 'newname',
            toys_attributes: [
              { name: 'ball' }
          ]
          }
          ])
          created = p.reload.pets.first
          expect(created.id).to eq(pet.id)
          expect(created.name).to eq('original')
          expect(created.toys.first.name).to eq('ball')
        end
      end
    end

    context 'when passing id in one record, attributes in another' do
      it 'should associate the id record, create the other' do
        existing = Pet.create!(name: 'original')
        p = Person.create!(pets_attributes: [{ id: existing.id}, { name: 'spot' }])
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
end
