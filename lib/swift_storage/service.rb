require 'uri'
require 'json'
require 'swift_storage/auth/v1_0'
require 'swift_storage/auth/v2_0'

class SwiftStorage::Service
  include SwiftStorage::Utils
  include SwiftStorage
  extend Forwardable
  def_delegators SwiftStorage, :configuration

  attr_reader          :tenant,
                       :endpoint,
                       :storage_url,
                       :auth_token,
                       :auth_at,
                       :expires,
                       :storage_token,
                       :storage_scheme,
                       :storage_host,
                       :storage_port,
                       :storage_path,
                       :temp_url_key,
                       :retries

  def initialize(tenant: configuration.tenant,
                 username: configuration.username,
                 password: configuration.password,
                 endpoint: configuration.endpoint,
                 temp_url_key: configuration.temp_url_key,
                 retries: configuration.retries)
    @temp_url_key = temp_url_key
    @retries = retries

    %w(tenant username password endpoint).each do |n|
      eval("#{n} or raise ArgumentError, '#{n} is required'")
      eval("@#{n} = #{n}")
    end

    setup_auth
    @sessions = {}
  end

  def setup_auth
    case configuration.auth_version
    when '1.0'
      extend SwiftStorage::Auth::V1_0
    when '2.0'
      extend SwiftStorage::Auth::V2_0
    else
      fail "Unsupported auth version #{configuration.auth_version}"
    end
  end

  def containers
    @container_collection ||= SwiftStorage::ContainerCollection.new(self)
  end

  def account
    @account ||= SwiftStorage::Account.new(self, tenant)
  end

  def storage_url=(new_url)
    uri = URI.parse(new_url)
    @storage_url = new_url
    @storage_scheme = uri.scheme
    @storage_host = uri.host
    @storage_port = uri.port
    @storage_path = uri.path
  end

  def create_temp_url(container, object, expires, method, options = {})

    scheme = options[:scheme] || storage_scheme

    method = method.to_s.upcase
    # Limit methods
    %w{GET PUT HEAD}.include?(method) or raise ArgumentError, 'Only GET, PUT, HEAD supported'

    expires = expires.to_i
    object_path_escaped = File.join(storage_path, escape(container), escape(object, '/'))
    object_path_unescaped = File.join(storage_path, escape(container), object)

    string_to_sign = "#{method}\n#{expires}\n#{object_path_unescaped}"

    sig = sig_to_hex(hmac('sha1', temp_url_key, string_to_sign))

    klass = scheme == 'http' ? URI::HTTP : URI::HTTPS

    temp_url_options = {
      scheme: scheme,
      host: storage_host,
      port: storage_port,
      path: object_path_escaped,
      query: URI.encode_www_form(
        temp_url_sig: sig,
        temp_url_expires: expires
      )
    }
    klass.build(temp_url_options).to_s
  end


  # CGI.escape, but without special treatment on spaces
  def self.escape(str, extra_exclude_chars = '')
    str.gsub(/([^a-zA-Z0-9_.-#{extra_exclude_chars}]+)/) do
      '%' + $1.unpack('H2' * $1.bytesize).join('%').upcase
    end
  end

  def escape(*args)
    self.class.escape(*args)
  end

  def request(path_or_url,
      method: :get,
      headers: nil,
      params: nil,
      json_data: nil,
      input_stream: nil,
      output_stream: nil)

    tries = retries

    headers ||= {}
    headers.merge!(Headers::AUTH_TOKEN => auth_token) if authenticated?
    headers.merge!(Headers::CONTENT_TYPE => 'application/json') if json_data
    headers.merge!(Headers::CONNECTION => 'keep-alive', Headers::PROXY_CONNECTION => 'keep-alive')

    if !(path_or_url =~ /^http/)
      path_or_url = File.join(storage_url, path_or_url)
    end

    # Cache HTTP session as url with no path (scheme, host, port)
    uri = URI.parse(URI.escape path_or_url)
    path = uri.query ? uri.path + '?' + uri.query : uri.path
    uri.path = ''
    uri.query = nil
    key = uri.to_s

    if sessions[key].nil?
      s = sessions[key] = Net::HTTP.new(uri.host, uri.port)
      s.use_ssl = uri.scheme == 'https'
      #s.set_debug_output($stderr)
      s.keep_alive_timeout = 30
      s.start
    end
    s = sessions[key]

    case method
    when :get
      if params.respond_to?(:to_hash)
        params.reject!{|k,v| v.nil?}
        path << '?'
        path << URI.encode_www_form(params)
      end
      req = Net::HTTP::Get.new(path, headers)
    when :delete
      req = Net::HTTP::Delete.new(path, headers)
    when :head
      req = Net::HTTP::Head.new(path, headers)
    when :post
      req = Net::HTTP::Post.new(path, headers)
    when :put
      req = Net::HTTP::Put.new(path, headers)
    when :copy
      req = Net::HTTP::Copy.new(path, headers)
    else
      raise ArgumentError, "Method #{method} not supported"
    end

    if json_data
      req.body = JSON.generate(json_data)
    end

    if input_stream
      if String === input_stream
        input_stream = StringIO.new(input_stream)
      end
      req.body_stream = input_stream
      req.content_length = input_stream.size
    end

    if output_stream
      output_proc = proc do |response|
        response.read_body do |chunk|
          output_stream.write(chunk)
        end
      end
    end

    begin
      response = s.request(req, &output_proc)
    rescue Errno::EPIPE, Errno::EAGAIN, Errno::EWOULDBLOCK, Timeout::Error, Errno::EINVAL, EOFError
      # Server closed the connection, retry
      sleep 5
      retry unless (tries -= 1) <= 0
      raise OpenStack::Exception::Connection, "Unable to connect to OpenStack::Swift after #{retries} retries"
    end

    begin
      check_response!(response)
    rescue AuthError
      # If token is at least 60 second old, we try to get a new one
      if @auth_at && (Time.now - @auth_at).to_i > 60
        authenticate!
        response = s.request(req, &output_proc)
      else
        raise
      end
    end
    response
  end

  private

  attr_reader          :sessions,
                       :username,
                       :password

  def check_response!(response)
    case response.code
    when /^2/
      return true
    when '401'
      raise AuthError, response.body
    when '403'
      raise ForbiddenError, response.body
    when '404'
      raise NotFoundError, response.body
    else
      raise ServerError, response.body
    end
  end

end
