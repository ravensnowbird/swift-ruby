module SwiftStorage
  module Auth
    module V2_0
      extend Forwardable
      def_delegators SwiftStorage, :configuration

      attr_accessor :auth_path

      def authenticate!
        res = request("#{auth_url}/tokens", method: :post, json_data: auth_data)

        JSON.parse(res.body).tap do |body|
          @auth_token = body['access']['token']['id']
          storage_endpoint(body['access']['serviceCatalog']) do |endpoint|
            self.storage_url = endpoint['publicURL']
            @storage_token = endpoint['id']
            @auth_at = Time.now
          end
        end
      end

      def authenticated?
        !!(self.storage_url && auth_token)
      end

      private

      def auth_url
        File.join(endpoint, @auth_path || 'v2.0').chomp('/')
      end

      def auth_data
        case configuration.auth_method
        when :password
          {
            auth: {
              passwordCredentials: {
                username: username,
                password: password
              },
              configuration.authtenant_type => tenant || username
            }
          }
        when :rax_kskey
          {
            auth: {
              'RAX-KSKEY:apiKeyCredentials' => {
                username: username,
                apiKey: password
              }
            }
          }
        when :key
          {
            auth: {
              apiAccessKeyCredentials: {
                accessKey: username,
                secretKey: password
              },
              configuration.authtenant_type => tenant || username
            }
          }
        else
          fail "Unsupported authentication method #{configuration.auth_method}"
        end
      end

      def storage_endpoint(service_catalog)
        unless (swift = service_catalog.find { |service| service['type'] == 'object-store' })
          fail 'No object-store service found'
        end
        yield swift['endpoints'].sample
      end
    end
  end
end
