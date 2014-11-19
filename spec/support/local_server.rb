require 'rack'
require 'rack/handler/webrick'
require 'net/http'
require 'securerandom'

# The code for this is inspired by Capybara's server:
#   http://github.com/jnicklas/capybara/blob/0.3.9/lib/capybara/server.rb
class LocalTestServer

  READY_MESSAGE = SecureRandom.hex(32)

  class TestApp
    attr_accessor          :last_env

    attr_accessor          :mock_status,
                           :mock_headers,
                           :mock_body

    def initialize
    end

    def call(env)
      if env["PATH_INFO"] == "/__ping__"
        [200, {}, [LocalTestServer::READY_MESSAGE]]
      else
        @last_env = env
        [mock_status || 200, mock_headers || {}, [mock_body || '']]
      end
    end

    def reset
      @last_env = @mock_status = @mock_headers = @mock_body = nil
    end
  end

  attr_accessor          :port,
                         :app

  def initialize
    @port = find_available_port
  end

  def base_url
    "http://127.0.0.1:#{port}"
  end

  def run
    Thread.new do
      opts = {
        :AccessLog => [],
        :Logger => WEBrick::BasicLog.new(StringIO.new),
        :Port => @port
      }
      @app = TestApp.new
      Rack::Handler::WEBrick.run(app, opts)
    end
    wait_until(10, "Test server start failed.") { running? }
  end

  private

  def find_available_port
    server = TCPServer.new('127.0.0.1', 0)
    server.addr[1]
  ensure
    server.close if server
  end

  def wait_until(timeout, error_message, &block)
    start_time = Time.now

    while true
      return if yield
      raise TimeoutError.new(error_message) if (Time.now - start_time) > timeout
      sleep(0.05)
    end
  end

  def running?
    res = Typhoeus.get("#{base_url}/__ping__")
    res.success? && res.body == LocalTestServer::READY_MESSAGE
  end

end
