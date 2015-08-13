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

  describe '#copy_from' do
    subject { swift_service.containers['some_destination_container'].objects['some_copied_object'] }
    let(:source) { swift_service.containers['some_source_container'].objects['some_object'] }

    it 'adds optional headers to request' do
      expect { subject.copy_from(source, 'X-Object-Falcon' => 'Awesome') }.to send_request(
        :copy,
        '/v1/AUTH_test/some_source_container/some_object',
        headers: { h::DESTINATION => 'some_destination_container/some_copied_object', 'X-Object-Falcon' => 'Awesome' }
      )
    end

    context 'when source is a SwiftStorage::Object' do
      it 'copies the source' do
        expect { subject.copy_from(source) }.to send_request(
          :copy,
          '/v1/AUTH_test/some_source_container/some_object',
          headers: { h::DESTINATION => 'some_destination_container/some_copied_object' }
        )
      end
    end

    context 'when source is a string' do
      it 'copies the source' do
        expect { subject.copy_from(source.relative_path) }.to send_request(
          :copy,
          '/v1/AUTH_test/some_source_container/some_object',
          headers: { h::DESTINATION => 'some_destination_container/some_copied_object' }
        )
      end
    end

    context 'when source is an integer' do
      it 'raises an error' do
        expect { subject.copy_from(42) }.to raise_error(ArgumentError, 'Invalid source type')
      end
    end

    it 'returns destination object' do
      expect(subject.copy_from(source).relative_path).to eq('some_destination_container/some_copied_object')
    end
  end
end
