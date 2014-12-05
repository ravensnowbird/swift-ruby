require "time"

# @attr [String] content_length
#  Content length of the Object, in bytes.
#
# @attr [String] content_type
#  Content type of the Object, eg: `image/png`.
#
# @attr [String] expires
#  When the object is set to expire.
#
# @attr [String] cache_control
#  Object cache control header.
#
class SwiftStorage::Object < SwiftStorage::Node


  parent_node                :container


  header_attributes          :content_length,
                             :content_type,
                             :expires,
                             :cache_control

  # Read the object data
  #
  # This will always make a request to the API server and will not use cache
  #
  # @param output_stream [IO]
  #  An optional stream to write the object's content to. This can be a `File` or and `IO` object.
  #  This method will **NEVER** rewind `output_stream`, either before writing and after.
  #
  # @return [String, output_stream]
  #  If `output_stream` is nil or ommited, it returns a string with the object content. If `output_stream`
  #  is given, returns it.
  #
  def read(output_stream=nil)
    response = request(relative_path, :method => :get, :output_stream => output_stream)
    if output_stream
      output_stream
    else
      response.body
    end
  end

  # Stream the object data to a file
  #
  # This will always make a request to the API server and will not use cache
  #
  # @param output_path [String]
  #  The path to the output file.
  #
  # @return [output_path]
  #  The passed path.
  #
  def stream_to_file(output_path)
    open(output_path, 'wb') do |io|
      read(io)
    end
    output_path
  end


  # Write the object
  #
  # This will always make a request to the API server and will not use cache
  #
  # @note If you want to only update the metadata, you may omit `input_stream`
  #  but you must specify all other options otherwise they will be overwritten.
  #
  # @note Some headers specified here may not work with a specific swift server
  #  as they must be enabled in the server configuration.
  #
  # @param input_stream [String, IO]
  #  The data to upload, if ommited, the write will not override the body and instead it will update
  #  the metadata and other options. If `input_stream` is an `IO` object, it must
  #  be seeked to the proper position, this method will **NEVER** seek or rewind the stream.
  #
  # @param content_type [String]
  #  The content type, eg: `image/png`.
  #
  # @param attachment [Boolean]
  #  If `true` the file will be served with `Content-Disposition: attachment`.
  #
  # @param delete_at [Time]
  #  If set, the server will delete the object at the specified time.
  #
  # @param delete_after [Time]
  #  If set, the server will delete the object after the specified time.
  #
  # @param cache_control [String]
  #  The value for the 'Cache-Control' header when serving the object. The value
  #  is not parsed and served unmodified as is. If you set max-age, it will
  #  always be served with the same max-age value. To have the resource expire
  #  at point of time, use the expires header.
  #
  # @param expires [Symbol, Time]
  #  Set the Expires header.
  #  Expires may also have the special value `:never` which override
  #  `cache_control` and set the expiration time in a long time.
  #
  # @param object_manifest [String]
  #  When set, this object acts as a large object manifest. The value should be
  #  `<container>/<prefix>` where `<container>` is the container the object
  #  segments are in and `<prefix>` is the common prefix for all the segments.
  #
  # @return [input_stream]
  #   Return the `input_stream` argument, or `nil` if `input_stream` is ommited.
  #
  def write(input_stream=nil,
            content_type: nil,
            attachment: false,
            delete_at: nil,
            delete_after: nil,
            cache_control: nil,
            expires: nil,
            object_manifest: nil,
            metadata: nil)

    h = {}

    input_stream.nil? or content_type or raise ArgumentError, 'Content_type is required if input_stream is given'

    object_manifest.nil? or input_stream.nil? or raise ArgumentError, 'Input must be nil on object manigest'

    if expires == :never
      expires = Time.at(4_000_000_000)
      cache_control = "public, max_age=4000000000"
    end

    h[H::CONTENT_DISPOSITION] = attachment ? 'attachment' : 'inline'
    h[H::OBJECT_MANIFEST] = object_manifest if object_manifest
    h[H::CONTENT_TYPE] = content_type if content_type
    h[H::EXPIRES] = expires.httpdate if expires
    h[H::CACHE_CONTROL] = cache_control if cache_control

    if delete_at
      h[H::DELETE_AT] = delete_at.to_i.to_s
    elsif delete_after
      h[H::DELETE_AFTER] = delete_after.to_i.to_s
    end

    merge_metadata(h, metadata)

    method =  input_stream || object_manifest ? :put : :post

    request(relative_path,
            :method => method,
            :headers => h,
            :input_stream => input_stream)
    clear_cache
    input_stream
  end


  # Generates a public URL with an expiration time
  #
  # @param expires [Time]
  #  The absolute time when the URL will expire.
  #
  # @param method [Symbol]
  #  The HTTP method to allow, can be `:get, :put, :head`.
  #
  # @return [String]
  #  A temporary URL to the object.
  #
  # @!parse def temp_url(expires=Time.now + 3600, method: :get);end
  def temp_url(expires=nil, method: :get)
    expires ||= Time.now + 3600
    service.create_temp_url(container.name, name, expires, method)
  end

  # Returns the object's URL
  #
  # @note This URL is unsigneds and the container authorization will apply. If
  #  the container do not allow public access, this URL will require an
  #  authentication token.
  #
  # @return [String]
  #  The object URL.
  #
  def url
    File.join(service.storage_url, relative_path)
  end

  private

  H = SwiftStorage::Headers

  def relative_path
    File.join(container.name, name)
  end

end

