# @attr [String] content_length
#  Content length of the Object, in bytes.
#
# @attr [String] content_type
#  Content type of the Object, eg: `image/png`.
#
class SwiftStorage::Object < SwiftStorage::Node

  include SwiftStorage

  parent_node                :container


  header_attributes          :content_lenght,
                             :content_type

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


  # Write the object
  #
  # This will always make a request to the API server and will not use cache
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
  # @return [input_stream]
  #   Return the `input_stream` argument, or `nil` if `input_stream` is ommited.
  #
  def write(input_stream=nil,
            content_type: nil,
            attachment: false,
            delete_at: nil,
            delete_after: nil,
            metadata: nil)

    h = {
      Headers::CONTENT_DISPOSITION => attachment ? 'attachment' : 'inline'
    }

    input_stream.nil? or content_type or raise ArgumentError, 'Content_type is required if input_stream is given'

    h[Headers::CONTENT_TYPE] = content_type || ''

    if delete_at
      h[Headers::DELETE_AT] = delete_at.to_i
    elsif delete_after
      h[Headers::DELETE_AFTER] = delete_after.to_i
    end

    merge_metadata(h, metadata)

    request(relative_path,
            :method => (input_stream ? :put : :post),
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
  # @note This URL is unsigned and the container authorization will apply. If
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
  def relative_path
    File.join(container.name, name)
  end

end

