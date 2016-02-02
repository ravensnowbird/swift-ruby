module SwiftStorage
  class Configuration
    attr_accessor :auth_version, :ssl_verify,
      :tenant, :username, :password, :endpoint, :temp_url_key,
      :auth_method, :authtenant_type, :retries

    def initialize
      @auth_version = ENV['SWIFT_STORAGE_AUTH_VERSION'] || '1.0'
      @ssl_verify = true
      @tenant = ENV['SWIFT_STORAGE_TENANT']
      @username = ENV['SWIFT_STORAGE_USERNAME']
      @password = ENV['SWIFT_STORAGE_PASSWORD']
      @endpoint = ENV['SWIFT_STORAGE_ENDPOINT']
      @temp_url_key = ENV['SWIFT_STORAGE_TEMP_URL_KEY']
      @retries = 3

      @auth_method = :password
      @authtenant_type = 'tenantName' # `tenantName` or `tenantId`
    end
  end
end
