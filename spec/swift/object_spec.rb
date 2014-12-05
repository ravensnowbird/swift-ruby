require "spec_helper"

RSpec.describe SwiftStorage::Object do
  subject { swift_service.containers['somecontainer'].objects['someobject'] }
  it "read" do
    headers(
      'X-Object-Meta-Foo' => 'foometa',
      'X-Object-Meta-Bar' => 'barmeta',
      'Content-Type' => 'image/png'
    )
    b = "o" * random_length
    body(b)

    expect{ subject.read }.to send_request(:get, '/v1/AUTH_test/somecontainer/someobject')

    expect(subject.metadata.foo).to eq('foometa')
    expect(subject.metadata.bar).to eq('barmeta')
    expect(subject.content_length).to eq(b.length.to_s)
    expect(subject.content_type).to eq('image/png')
    expect(subject.read).to eq(b)
  end

  it "write" do
    headers(
      'X-Object-Meta-Jon-Doe' => 'a meta'
    )

    b = "0" * random_length
    expect {
      subject.write(b,
                    :content_type => 'image/png',
                    :attachment => true,
                    :delete_at => Time.at(4000),
                    :metadata => {:foo => :bar, :jon => :doe, 'WeiRd ^^!+Format With!! Spaces $$$' => 'weird'})
    }.to send_request(:put, '/v1/AUTH_test/somecontainer/someobject',
                      :headers => {
      'Content-Length' => b.length,
      'Content-Disposition' => 'attachment',
      'X-Delete-At' => 4000,
      'X-Object-Meta-Foo' => 'bar',
      'X-Object-Meta-Jon' => 'doe',
      'X-Object-Meta-Weird-Format-With-Spaces' => 'weird',
    }, :body => b)
    expect(subject.metadata.jon_doe).to eq('a meta')
  end

end
