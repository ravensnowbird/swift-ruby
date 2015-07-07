require "swift-storage"
require_relative "support/local_server"

module TestServerMixin
  def h
    SwiftStorage::Headers
  end

  def self.run
    @server = LocalTestServer.new
    @server.run
  end

  def self.server
    @server
  end

  def self.reset
    @server.app.reset
  end

  def server
    TestServerMixin.server
  end

  def swift_service
    service = SwiftStorage::Service.new(:tenant => 'test',
                                        :username => 'testuser',
                                        :password => 'testpassword',
                                        :endpoint => server.base_url,
                                        :temp_url_key => 'A1234'
                                       ).tap { |s| s.storage_url = test_storage_url }
  end

  def test_storage_url
    File.join(server.base_url, 'v1/AUTH_test')
  end

  def headers(new_headers)
    server.app.mock_headers = new_headers
  end

  def status(new_status)
    server.app.mock_status = new_status
  end

  def body(new_body)
    server.app.mock_body = new_body
  end

  def random_length
    Random.rand(5000) + 1000
  end


end

RSpec::Matchers.define :send_request do |method, path, options={}|
  headers = options[:headers]
  body = options[:body]
  params = options[:params]
  match do |actual|
    actual.call()
    env = server.app.last_env

    @actual_method = env['REQUEST_METHOD'].downcase
    @actual_path = env['PATH_INFO']
    @actual_body = env['rack.input'].read

    @method_match = @actual_method == method.to_s.downcase

    @path_match = @actual_path == path
    @headers_match = true

    headers.each_pair do |k,v|
      k = k.gsub('-', '_').upcase
      actual_value =  env[k] || env["HTTP_#{k}"]
      if v.to_s != actual_value.to_s
        @unatched_header = "Header #{k} should be #{v}, got #{actual_value||'null'}"
        @headers_match = false
        break
      end
    end if headers
    @body_match = true
    @body_match = @actual_body == body if body

    @params_match = true
    if params
      @actual_params = env['QUERY_STRING']
      @params_string = URI.encode_www_form(params)
      @params_match = @params_string == @actual_params
    end

    @method_match && @path_match && @headers_match && @body_match && @params_match
  end

  failure_message do
    r = []
    r << "Method should be #{method}, got #{@actual_method}" if !@method_match
    r << "Path should be #{path}, got #{@actual_path}" if !@path_match
    r << "Unmatched headers #{@unatched_header}" if !@headers_match
    r << "Body doesn't match, for #{@actual_body} expected #{body}" if !@body_match
    r << "Params should be #{@params_string}, got #{@actual_params}" if !@params_match
    r.join("\n")
  end

  def supports_block_expectations?
    true
  end

end

RSpec.configure do |config|

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end


  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  config.disable_monkey_patching!

  if config.files_to_run.one?
    config.default_formatter = 'doc'
  end

  config.profile_examples = 10

  config.order = :random

  Kernel.srand(config.seed)

  config.include(TestServerMixin)

  config.before(:suite) do
    TestServerMixin.run
  end

  config.before(:each) do
    TestServerMixin.reset
  end

end
