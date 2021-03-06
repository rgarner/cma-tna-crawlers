require 'spec_helper'
require 'cma/oft/mergers/case'
require 'nokogiri'

module CMA::OFT::Mergers
  describe Case do
    let(:old_style_url) {
      'http://http:/www.oft.gov.uk/OFTwork/mergers/Mergers_Cases/2008/coop-somerfield'
    }
    let(:new_style_url) {
      'http://www.oft.gov.uk/OFTwork/mergers/decisions/2013/ABNAmro'
    }
    describe '#title_is_summary? / #old_style?' do
      Given(:_case) { Case.create(original_url, 'title') }

      context 'the case came from an 2002-2009 URL' do
        Given(:original_url) { old_style_url }

        Then { _case.old_style?        == true  }
        And  { _case.new_style?        == false }
        And  { _case.title_is_summary? == false }
      end

      context 'the case came from an 2010- URL' do
        Given(:original_url) { new_style_url }

        Then { _case.old_style?        == false }
        And  { _case.new_style?        == true }
        And  { _case.title_is_summary? == true }
      end
    end

    describe '#case_type' do
      Given(:_case) { Case.create('http://example.com/merger', 'title') }

      Then { _case.case_type == 'mergers' }

      describe '#case_type=' do
        When { _case.case_type = 'something-else' }

        Then { _case.case_type == 'something-else' }
      end
    end

    describe '#add_summary' do
      Given(:_case) { Case.create(original_url, 'title') }
      Given(:doc)   { Nokogiri::HTML(File.read('spec/fixtures/oft/abn-amro.html'))}

      When(:result) { _case.add_summary(doc) }

      context "this is not a new-style case, so there's no summary to add" do
        Given(:original_url) { old_style_url }

        Then { result == Failure(ArgumentError, /not a new-style case/) }
      end

      context 'this is a new-style case' do
        Given(:original_url) { new_style_url }

        it 'sets the summary to the title of the page' do
          expect(_case.summary).to eql(
           'OFT closed case: '\
           'Anticipated acquisition by ABN Amro Clearing Bank N.V., OMX A.B., '\
           'BATS Trading Limited and the Depository Trust & Clearing '\
           'Corporation of European Multilateral Clearing Facility N.V., '\
           'including the transfer of certain assets to EMCF from EuroCCP'
          )
        end
      end
    end

    describe '#needs_fntq_body?' do
      context 'with a new-style case that is Found Not To Qualify' do
        let(:_case) { Case.create('http://example.com', 'title') }

        subject { _case.needs_fntq_body?(doc) }

        context 'when it has the full text of the decision as a download' do
          let(:doc) { Nokogiri::HTML(File.read('spec/fixtures/oft/sports-direct-fntq-with-pdf.html')) }
          it { should be_falsey }
        end

        context 'when it has the full text of the decision in the HTML' do
          let(:doc) { Nokogiri::HTML(File.read('spec/fixtures/oft/accraply-fntq-no-pdf.html')) }
          it { should be_truthy }
        end

        context 'when it has text in the PDF and has been abandoned' do
          let(:doc) { Nokogiri::HTML(File.read('spec/fixtures/oft/costain-abandoned.html')) }
          it { should be_truthy }
        end
      end

    end

    describe '#add_subpage' do
      Given(:_case) { Case.create('http://example.com/1', 'title') }

      When { _case.add_subpage(doc) }

      context 'LSE subpage' do
        let(:doc) do
          Nokogiri::HTML(File.read('spec/fixtures/oft/decisions-2010-lse.html'))
        end

        Then { expect(_case.original_urls).to include(
          'http://www.oft.gov.uk/OFTwork/mergers/decisions/2010/london-stock-exchange')
        }

        And {
          _case.summary == 'OFT closed case: '\
            'Anticipated acquisition by London Stock Exchange Group Plc '\
            'of Turquoise Trading Limited'
        }

        describe 'the markdown section' do
          subject(:section) do
            _case.markup_sections['decisions/2010/london-stock-exchange']
          end

          it { should include('Anticipated acquisition by London Stock Exchange Group Plc') }
          it { should_not include('<div') }
        end
      end
    end
  end
end
