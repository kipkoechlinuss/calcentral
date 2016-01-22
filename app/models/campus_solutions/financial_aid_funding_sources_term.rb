module CampusSolutions
  class FinancialAidFundingSourcesTerm < Proxy

    include FinaidFeatureFlagged
    include CampusSolutionsIdRequired

    def initialize(options = {})
      super options
      @aid_year = options[:aid_year] || '0'
      initialize_mocks if @fake
    end

    def xml_filename
      'financial_aid_funding_sources_term.xml'
    end

    def build_feed(response)
      return {} if response.parsed_response.blank?
      response.parsed_response['ROOT']
    end

    def url
      "#{@settings.base_url}/UC_FA_FUNDING_SOURCES_TERM.v1/get?EMPLID=#{@campus_solutions_id}&INSTITUTION=UCB01&AID_YEAR=#{@aid_year}"
    end

  end
end