module Cal1card
  class MyCal1card < UserSpecificModel
    include Cache::CachedFeed
    include Cache::FeedExceptionsHandled
    include Cache::JsonAddedCacher
    include Cache::UserCacheExpiry
    include Proxies::HttpClient
    include Proxies::MockableXml

    def initialize(uid, options={})
      super(uid, options)
      @settings = Settings.cal1card_proxy
      @fake = (options[:fake] != nil) ? options[:fake] : @settings.fake
      initialize_mocks if @fake
    end

    def default_message_on_exception
      'An error occurred retrieving data for Cal 1 Card. Please try again later.'
    end

    def get_feed_internal
      if Settings.features.cal1card
        get_converted_xml
      else
        {}
      end
    end

    def get_converted_xml
      logger.info "Internal_get: Fake = #{@fake}; Making request to #{url} on behalf of user #{@uid}; cache expiration #{self.class.expires_in}"
      response = get_response(
        url,
        query: {uid: @uid},
        basic_auth: {username: @settings.username, password: @settings.password}
      )
      feed = response.parsed_response
      logger.debug "Cal1Card remote response: #{response.inspect}"

      camelized = HashConverter.camelize feed
      camelized[:cal1card].merge({
        statusCode: 200
      })
    end

    def url
      "#{@settings.base_url}/csc.asp"
    end

    def mock_request
      super.merge({
        uri_matching: url,
        query: {uid: @uid}
      })
    end

    def mock_xml
      read_file('fixtures', 'xml', 'cal1card_feed.xml')
    end
  end
end

