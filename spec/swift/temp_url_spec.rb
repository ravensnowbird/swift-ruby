require "spec_helper"

RSpec.describe 'Temporary URL' do
  subject { swift_service }
  it "creates an url" do
    headers(
      h::STORAGE_URL => test_storage_url,
      h::AUTH_TOKEN => 'auth_token',
      h::STORAGE_TOKEN => 'storage_token'
    )
    subject.authenticate!

    # This has been computed manually and checked with openstack
    # Only server port vary, not actual host
    url = "http://127.0.0.1:#{server.port}/v1/AUTH_test/testbucket/test.html?temp_url_sig=4db4c16c859fdddca2e629a0a1e6b81c15a42cbd&temp_url_expires=50000"
    expect(subject.create_temp_url('testbucket', 'test.html', 50000, 'GET')).to eq(url)
  end
end

