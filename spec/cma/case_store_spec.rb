require 'spec_helper'
require 'cma/case_store'

module CMA
  describe CaseStore do
    describe '#location' do
      context 'with no location' do
        it 'defaults to _output' do
          expect(CaseStore.new.location).to eql('_output')
        end
      end

      context 'with a given location' do
        it 'points to that location' do
          expect(CaseStore.new('spec/fixtures/store').location).to eql('spec/fixtures/store')
        end
      end
    end

    describe '#save' do
      let(:case_store) { CaseStore.new('spec/fixtures/store') }

      before { FileUtils.rmtree(case_store.location) }
      after  { FileUtils.rmtree(case_store.location) }

      context 'when the object to save is not serializable to JSON' do
        it 'fails but leaves the dir' do
          expect { case_store.save(1, 'filename.json') }.
            to raise_error(ArgumentError, /Case must be serializable to JSON/)
          expect(Dir).to exist(case_store.location)
        end
      end

      context 'when the object to save is serializable to JSON' do
        let(:case_content) { {'a' => 'b'} }

        before { case_store.save(case_content, 'ab-hash.json') }

        it 'saves the object to the location' do
          expect(File).to exist('spec/fixtures/store/ab-hash.json')
        end

        it 'saves the object as JSON' do
          reparsed_json = JSON.parse(File.read('spec/fixtures/store/ab-hash.json'))
          expect(reparsed_json).to eql(case_content)
        end
      end
    end
  end
end
