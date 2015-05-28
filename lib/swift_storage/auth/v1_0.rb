module SwiftStorage
  module Auth
    module V1_0
      attr_accessor :auth_path

      def authenticate!
         headers = {
           Headers::AUTH_USER => "#{tenant}:#{username}",
           Headers::AUTH_KEY => password
         }
         res = request(auth_url, headers: headers)

         h = res.header
         storage_url = h[Headers::STORAGE_URL]
         @auth_token = h[Headers::AUTH_TOKEN]
         @storage_token = h[Headers::STORAGE_TOKEN]
         @auth_at = Time.now
       end

      def authenticated?
        !!(storage_url && auth_token)
      end

      private

      def auth_url
        File.join(endpoint, @auth_path || 'auth/v1.0')
      end
    end
  end
end
