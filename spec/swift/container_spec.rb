require "spec_helper"

RSpec.describe SwiftStorage::Container do
  subject { swift_service.containers['test'] }
  it "list with prefix" do
    expect{ subject.objects.with_prefix('foo/bar') }.to(
      send_request(:get, '/v1/AUTH_test/test',
                   :params => {:prefix => 'foo/bar'})
    )
  end
end

