require 'httpclient'

class Capybara::HTTPClientJson::Driver < Capybara::Json::Driver::Base
  attr_reader :app, :options, :current_url, :response, :cookies

  def client
    unless @client
      @client = HTTPClient.new
      @client.follow_redirect_count  = 5 + 1 # allows 5 redirection
      @client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE

      # hack for redirect
      def @client.redirect_uri_callback_to_keep_new_uri(uri, res)
        new_uri = default_redirect_uri_callback(uri, res)
        @new_uri = new_uri
      end
      @client.redirect_uri_callback = @client.method(:redirect_uri_callback_to_keep_new_uri)
    end
    @client
  end

  def initialize(app, options = {})
    @app, @options = app, { :follow_redirect => true }.merge(options)
    @rack_server = Capybara::Server.new(@app)
    @rack_server.boot if Capybara.run_server
  end

  def status_code
    response.code
  end

  def source
    response.body
  end

  # Capybara changed this in capybara-2.0
  def body
    ::Capybara::VERSION =~ /^2/ ? source : json
  end

  def json
    ::MultiJson.load(source) || {}
  end

  def response_headers
    response.headers
  end

  def get(url, params = {}, headers = {})
    process :get, url, params, headers, options[:follow_redirect]
  end
  alias visit get

  def post(url, json, headers = {})
    json = MultiJson.dump(json) unless json.is_a?(String)
    headers['Content-Type'] = "application/json; charset=#{json.encoding.to_s.downcase}"
    process :post, url, json, headers, options[:follow_redirect]
  end

  def put(url, json, headers = {})
    json = MultiJson.dump(json) unless json.is_a?(String)
    headers['Content-Type'] = "application/json; charset=#{json.encoding.to_s.downcase}"
    process :put, url, json, headers
  end

  def delete(url, params = {}, headers = {})
    process :delete, url, params, headers
  end

  %w[ get delete ].each do |method|
    class_eval %{
      def #{method}!(url, params = {}, env = {})
        handle_error { #{method}(url, params, env) }
      end
    }
  end

  %w[ post put ].each do |method|
    class_eval %{
      def #{method}!(url, json, headers = {})
        handle_error { #{method}(url, json, headers) }
      end
      }
  end

  def reset!
    @client = nil
  end

  def needs_server?
    true
  end

  protected
  def process(method, path, params = {}, headers = {}, options = {})
    @current_url = if path =~ %r<^http://>
      path
    else
      @rack_server ? @rack_server.url(path) : path # for Capybara 1.0
    end

    begin
      @response = client.__send__(method, @current_url, params, headers, options)

      # hack for redirect
      if new_uri = client.instance_variable_get(:@new_uri)
        @current_url = new_uri.to_s
        client.instance_variable_set(:@new_uri, nil)
      end
    rescue HTTPClient::BadResponseError => e
      if e.message == "retry count exceeded"
        raise Capybara::InfiniteRedirectError
      else
        @response = e.res
      end
    end
  end

  def handle_error(&block)
    yield
    raise(Capybara::Json::Error, response) if status_code >= 400
  end
end
