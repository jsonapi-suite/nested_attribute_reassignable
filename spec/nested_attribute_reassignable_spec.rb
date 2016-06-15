require 'spec_helper'

#ActiveRecord::Base.logger = Logger.new(STDOUT)

describe NestedAttributeReassignable do
  context 'when belongs_to' do
    context 'when passing id only' do
      it 'should assign the id as foreign key' do
        family = Family.create!
        p = Person.create!(family_attributes: { id: family.id })
        expect(p.family_id).to eq(family.id)
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
  end

  context 'when has_many' do
    context 'when passing only id' do
      it 'should associate the existing objects' do
        pets = [Pet.create!, Pet.create!]
        p = Person.create!(pets_attributes: [{ id: pets.first.id }, { id: pets.last.id }])
        expect(p.reload.pets).to eq(pets)
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
  end

  context 'when has_one' do
    it 'should associate the existing objects' do
      office = Office.create!
      p = Person.create!(office_attributes: { id: office.id })
      expect(p.reload.office).to eq(office)
    end
  end
end
