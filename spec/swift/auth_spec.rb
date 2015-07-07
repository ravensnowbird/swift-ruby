require 'spec_helper'

RSpec.describe 'Auth' do
  subject { swift_service }

  context 'when v1 is used' do
    before do
      headers(
        h::STORAGE_URL => test_storage_url,
        h::AUTH_TOKEN => 'auth_token',
        h::STORAGE_TOKEN => 'storage_token'
      )
    end

    it 'authenticates' do
      expect { subject.authenticate! }.to send_request(:get, '/auth/v1.0',
        headers: { h::AUTH_USER => 'test:testuser', h::AUTH_KEY => 'testpassword' })
    end

    it 'sets the authentication token' do
      subject.authenticate!
      expect(subject.auth_token).to eq('auth_token')
    end

    it 'sets the storage url' do
      subject.authenticate!
      expect(subject.storage_url).to eq(test_storage_url)
    end

    it 'sets the storage token' do
      subject.authenticate!
      expect(subject.storage_token).to eq('storage_token')
    end
  end

  context 'when v2 is used' do
    let(:credentials) do
      {
        auth: {
          passwordCredentials: {
            username: 'testuser',
            password: 'testpassword'
          },
          subject.configuration.authtenant_type => 'test'
        }
      }
    end
    let(:body) do
      {
        'access' => {
          'token' => {
            'id' => 'auth_token'
          },
          'serviceCatalog' => [
            {
              'endpoints' => [
                {
                  'id' => 'storage_token',
                  'publicURL' => test_storage_url
                }
              ],
              'type' => 'object-store'
            }
          ]
        }
      }
    end

    before do
      SwiftStorage.configuration.auth_version = '2.0'
      allow(JSON).to receive(:parse).and_return(body)
    end
    after { SwiftStorage.configuration.auth_version = '1.0' }

    it 'authenticates' do
      expect { subject.authenticate! }.to send_request(:post, '/v2.0/tokens',
        json_data: credentials.to_json)
    end

    it 'sets the authentication token' do
      subject.authenticate!
      expect(subject.auth_token).to eq('auth_token')
    end

    context 'when there is an object-store' do
      it 'sets the storage url' do
        subject.authenticate!
        expect(subject.storage_url).to eq(test_storage_url)
      end

      it 'sets the storage token' do
        subject.authenticate!
        expect(subject.storage_token).to eq('storage_token')
      end
    end

    context 'when there is no object-store' do
      let(:bad_body)  do
        {
          'access' => {
            'token' => {
              'id' => 'auth_token'
            },
            'serviceCatalog' => []
          }
        }
      end

      before do
        allow(JSON).to receive(:parse).and_return(bad_body)
      end

      it 'raises an error' do
        expect{ subject.authenticate! }
          .to raise_error(SwiftStorage::Service::NotFoundError, 'No object-store service found')
      end
    end
  end

  it 'failure' do
    status(401)

    expect{ subject.authenticate! }.to raise_error(SwiftStorage::Service::AuthError)
  end
end
