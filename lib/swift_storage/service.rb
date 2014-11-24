require 'uri'

class SwiftStorage::Service

  include SwiftStorage::Utils
  include SwiftStorage

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
    @temp_url_key = temp_url_key

    %w(tenant username password endpoint).each do |n|
      eval("#{n} or raise ArgumentError, '#{n} is required'")
      eval("@#{n} = #{n}")
    end

    @sessions = {}
  end

  def authenticate!
    headers = {
      Headers::AUTH_USER => "#{tenant}:#{username}",
      Headers::AUTH_KEY => password
    }
    res = request(auth_url, :headers => headers)

    h = res.header
    @storage_url = h[Headers::STORAGE_URL]
    uri = URI.parse(@storage_url)
    @storage_scheme = uri.scheme
    @storage_host = uri.host
    @storage_port = uri.port
    @storage_path = uri.path
    @auth_token = h[Headers::AUTH_TOKEN]
    @storage_token = h[Headers::STORAGE_TOKEN]
  end

  def authenticated?
    !!(storage_url && auth_token)
  end

  def containers
    @container_collection ||= SwiftStorage::ContainerCollection.new(self)
  end

  def account
    @account ||= SwiftStorage::Account.new(self, tenant)
  end

  def create_temp_url(container, object, expires, method, options = {})

    scheme = options[:scheme] || storage_scheme

    method = method.to_s.upcase
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

  def request(path_or_url,
              method: :get,
              headers: nil,
              input_stream: nil,
              output_stream: nil)
    headers ||= {}
    headers.merge!(Headers::AUTH_TOKEN => auth_token) if authenticated?
    headers.merge!(Headers::CONNECTION => 'keep-alive', Headers::PROXY_CONNECTION => 'keep-alive')

    if !(path_or_url =~ /^http/)
      base_url = storage_url || File.join(endpoint, 'v1', "AUTH_#{tenant}")
      path_or_url = File.join(base_url, path_or_url)
    end

    # Cache HTTP session as url with no path
    uri = URI.parse(path_or_url)
    path = uri.path
    uri.path = ''
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
      req = Net::HTTP::Get.new(path, headers)
    when :delete
      req = Net::HTTP::Delete.new(path, headers)
    when :head
      req = Net::HTTP::Head.new(path, headers)
    when :post
      req = Net::HTTP::Post.new(path, headers)
    when :put
      req = Net::HTTP::Put.new(path, headers)
    else
      raise ArgumentError, "Method #{method} not supported"
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

    response = s.request(req, &output_proc)
    check_response!(response)
    response
  end

  private

  attr_reader          :sessions,
                       :username,
                       :password

  def auth_url
    File.join(endpoint, 'auth/v1.0')
  end

  def check_response!(response)
    case response.code
    when /^2/
      return true
    when '401'
      raise AuthError
    when '403'
      raise AuthError
    when '404'
      raise NotFoundError
    else
      raise ServerError
    end
  end

end
