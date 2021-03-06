require 'cma/oft/current/crawler'
require 'cma/case_store/index'

module CMA
  module OFT
    ##
    # Crawl completed cases pages to mop up missing cases
    #
    class CompletedCrawler < CMA::OFT::Current::Crawler
      CONSUMER_ENFORCEMENT_COMPLETED = OFT_BASE + 'OFTwork/consumer-enforcement/consumer-enforcement-completed/'
      MARKETS_COMPLETED              = OFT_BASE + 'OFTwork/markets-work/completed/'

      def create_or_update_content_for(page)
        original_url = CMA::Link.new(page.url).original_url

        case original_url
        when CONSUMER_ENFORCEMENT_COMPLETED, MARKETS_COMPLETED
          CMA::OFT::YearCaseList.new(page.doc).save_to(
            case_store, noclobber: true)
        when CASE_DETAIL
          puts ' Case Detail'
          begin
            with_case(original_url, original_url) do |_case|
              _case.add_detail(page.doc)
            end
          rescue Errno::ENOENT
            puts 'Case not found:'
            dump_referer_chain(page)
            puts
          end
        when ASSET
          puts ' ASSET'
          return if page.referer.to_s =~ /doorstep-selling/
          begin
            with_nearest_case_matching(page.referer, CASE_DETAIL) do |_case|
              asset = CMA::Asset.new(original_url, _case, page.body, page.headers['content-type'].first)
              asset.save!(case_store.location)
              _case.assets << asset
            end
          rescue Errno::ENOENT
            puts 'Case not found for ASSET:'
            dump_referer_chain(page)
            puts
          end
        end
      end

      def crawl!
        FOLLOW_ONLY.delete(CASE)
        CMA::Filename::MAPPINGS.delete_if { true }

        cross_linked_cases.each { |url| IGNORE_EXPLICITLY << TNA_BASE + url }

        [
          MARKETS_COMPLETED,
          CONSUMER_ENFORCEMENT_COMPLETED
        ].map { |original_url| TNA_BASE + original_url }.each do |start_url|
          do_crawl(start_url,
                   newline_after_url: false,
                   print_referer: true) do |crawl|
            focus_on_interesting_body_copy_links(crawl)
          end
        end
      end

      def cross_linked_cases
        %w(
          http://www.oft.gov.uk/OFTwork/markets-work/mobility-aids/
          http://www.oft.gov.uk/OFTwork/markets-work/advertising-prices/
          http://www.oft.gov.uk/OFTwork/markets-work/off-grid/
          http://www.oft.gov.uk/OFTwork/markets-work/cars
          http://www.oft.gov.uk/OFTwork/markets-work/super-complaints/
          http://www.oft.gov.uk/OFTwork/markets-work/northernrockqanda
        )
      end
    end
  end
end
