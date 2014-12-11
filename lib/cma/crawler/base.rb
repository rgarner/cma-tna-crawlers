require 'anemone'
require 'cma/link'
require 'cma/case_store'
require 'cma/cc/case_list/page'
require 'cma/cc/case'

module CMA
  module Crawler
    class Base
      attr_accessor :case_store
      def initialize
        self.case_store = CaseStore.new
      end

      attr_reader :crawl
      def do_crawl(start_url, options = {})
        Anemone.crawl(start_url, options) do |crawl|
          crawl.on_every_page do |page|
            puts "#{page.code} #{page.url}#{' <- ' if page.referer}#{page.referer}"
            create_or_update_content_for(page)
          end

          @crawl = crawl
          yield @crawl
        end
      end

      def with_case(original_url, from = nil)
        _case = case_store.find(original_url)
        if _case
          _case.original_urls << from.to_s if from
          yield _case
          case_store.save(_case)
        else
          puts "*** WARN: case for #{original_url} not found"
        end
      end

      def with_nearest_case_matching(url, regex, from = nil, &block)
        page = find_nearest_page_matching(url, regex)
        raise Errno::ENOENT, "No page matching #{regex} available for #{url}" if page.nil?
        with_case(Link.new(page.url).original_url, from, &block)
      end

      ##
      # Use the Anemone page store to find the closest referer in the crawl tree
      # that is a case (or nil if any URL in the chain can't be found)
      def find_nearest_page_matching(url, regex)
        raise ArgumentError,
              'No crawl found. Set @crawl as the first thing in your Anemone.crawl block' if crawl.nil?

        page = @crawl.pages[url]
        return page if page.nil? || page.url.to_s =~ regex

        find_nearest_page_matching(page.referer, regex)
      end
    end
  end
end
