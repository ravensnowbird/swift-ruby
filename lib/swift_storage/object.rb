class SwiftStorage::Object < SwiftStorage::Node

  parent_node                :container

  header_prefix              'X-Object'.freeze

  header_attributes          :content_lenght

  # Read the object data
  #
  # This will always make a request to the API server and will not use cache
  #
  # @param output_stream [IO] An optional stream to write the object's content
  #                           to. This can be a `File` or and `IO` object.
  #                           This method will **NEVER** rewind `output_stream`,
  #                           either before writing and after.
  # @return [String, output_stream] If `output_stream` is nil or ommited, it returns a string
  #                                 with the object content. If `output_stream`
  #                                 is given, returns it.
  def read(output_stream=nil)
    response = request(relative_path, :method => :get, :output_stream => output_stream)
    if output_stream
      output_stream
    else
      response.body
    end
  end


  def write(input_stream=nil)
    request(relative_path, :method => :put, :input_stream => input_stream)
    input_stream
  end


  def temp_url(expires=nil)
    expires ||= Time.now + 3600
    service.create_temp_url(container.name, name, expires, 'GET')
  end

  def public_url
  end

  private
  def relative_path
    File.join(container.name, name)
  end

end

