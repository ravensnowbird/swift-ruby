require "swift-storage"
require_relative "support/local_server"

module TestServerMixin

  def h
    SwiftStorage::Service::Headers
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
                                       )
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


end

RSpec::Matchers.define :send_headers do |expected|
  match do |actual|
    actual.call()
    h = {}
    expected.each_pair do |k,v|
      h["HTTP_#{k.gsub('-', '_').upcase}"] = v
    end

    (h.to_a - server.app.last_env.to_a).empty?
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
