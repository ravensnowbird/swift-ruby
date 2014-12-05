require "spec_helper"

RSpec.describe 'Auth' do
  subject { swift_service }
  it "success" do
    headers(
      h::STORAGE_URL => test_storage_url,
      h::AUTH_TOKEN => 'auth_token',
      h::STORAGE_TOKEN => 'storage_token'
    )

    expect{ subject.authenticate! }.to send_request(:get, '/auth/v1.0', :headers => {
      h::AUTH_USER => 'test:testuser',
      h::AUTH_KEY => 'testpassword'
    })

    expect(subject.auth_token).to eq('auth_token')
    expect(subject.storage_url).to eq(test_storage_url)
    expect(subject.storage_token).to eq('storage_token')
  end

  it "failure" do
    status(401)

    expect{ subject.authenticate! }.to raise_error(SwiftStorage::Service::AuthError)
  end
end
