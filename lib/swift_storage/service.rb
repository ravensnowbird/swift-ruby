require 'uri'

class SwiftStorage::Service

  module Headers
    STORAGE_URL = 'X-Storage-Url'.freeze
    AUTH_TOKEN = 'X-Auth-Token'.freeze
    AUTH_USER = 'X-Auth-User'.freeze
    AUTH_KEY = 'X-Auth-Key'.freeze
    STORAGE_TOKEN = 'X-Storage-Token'.freeze
  end

  include Headers

  class AuthError < StandardError
  end


  attr_reader          :tenant,
                       :endpoint,
                       :storage_url,
                       :auth_token,
                       :storage_token,
                       :storage_scheme,
                       :storage_host,
                       :storage_port,
                       :storage_path,
                       :temp_url_key

  def initialize(tenant: ENV['SWIFT_STORAGE_TENANT'],
                 username: ENV['SWIFT_STORAGE_USERNAME'],
                 password: ENV['SWIFT_STORAGE_PASSWORD'],
                 endpoint: ENV['SWIFT_STORAGE_ENDPOINT'],
                 temp_url_key: ENV['SWIFT_STORAGE_TEMP_URL_KEY'])
    @tenant = tenant
    @username = username
    @password = password
    @endpoint = endpoint
    @temp_url_key = temp_url_key

    tenant or raise ArgumentError, 'Tenant is required'
    username or raise ArgumentError, 'Username is required'
    password or raise ArgumentError, 'Password is required'
    endpoint or raise ArgumentError, 'Endpoint is required'
    @hydra = Typhoeus::Hydra.hydra
  end

  def authenticate!
    headers = {
      'X-Auth-User' => "#{tenant}:#{username}",
      'X-Auth-Key' => password
    }
    res = request(auth_url, :headers => headers)
    res.success? or raise AuthError

    h = res.headers
    @storage_url = h[STORAGE_URL]
    uri = URI.parse(@storage_url)
    @storage_scheme = uri.scheme
    @storage_host = uri.host
    @storage_port = uri.port
    @storage_path = uri.path
    @auth_token = h[AUTH_TOKEN]
    @storage_token = h[STORAGE_TOKEN]

  end

  def authenticated?
    !!(storage_url && auth_token)
  end


  def create_temp_url(container, object, expires, method, options = {})

    scheme = options[:scheme] || storage_scheme

    # Limit methods
    %w{GET PUT HEAD}.include?(method) or raise ArgumentError, "Only GET, PUT, HEAD supported"

    expires = expires.to_i
    object_path_escaped = File.join(storage_path, escape(container), escape(object,"/"))
    object_path_unescaped = File.join(storage_path, escape(container), object)

    string_to_sign = "#{method}\n#{expires}\n#{object_path_unescaped}"

    sig  = sig_to_hex(hmac('sha1', temp_url_key, string_to_sign))

    klass = scheme == 'http' ? URI::HTTP : URI::HTTPS

    temp_url_options = {
      :scheme => scheme,
      :host => storage_host,
      :port => storage_port,
      :path => object_path_escaped,
      :query => URI.encode_www_form(
        :temp_url_sig => sig,
        :temp_url_expires => expires
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

  private

  attr_reader          :hydra,
                       :username,
                       :password


  def auth_url
    File.join(endpoint, 'auth/v1.0')
  end

  def request(path_or_url, method: :get, headers: nil, data: nil)
    headers ||= {}
    headers.merge!('X-Auth-Token' => auth_token) if authenticated?
    headers.merge!('Accept' => 'application/json')

    if !(path_or_url =~ /^http/)
      storage_url or raise ArgumentError, "Cannot make a path request (#{path_or_url}) with no storage URL"
      path_or_url = File.join(storage_url, path_or_url)
    end

    req = Typhoeus::Request.new(
      path_or_url,
      :method => method,
      :headers => headers
    )
    hydra.queue(req)
    hydra.run
    req.response
  end

  def hmac(type, key, data)
    digest = OpenSSL::Digest.new(type)
    OpenSSL::HMAC.digest(digest, key, data)
  end


  def sig_to_hex(str)
    str.unpack("C*").map { |c|
      c.to_s(16)
    }.map { |h|
      h.size == 1 ? "0#{h}" : h
    }.join
  end
end
