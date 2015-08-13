class SwiftStorage::Account < SwiftStorage::Node

  parent_node          :service


  # Write account meta data
  #
  # @param temp_url_key [String]
  #  The shared secret used to sign temporary URLs.
  #  Changing this key will invalidate all temporary URLs signed with the older
  #  key.
  #
  def write(temp_url_key: nil)
    h = {}
    h[H::ACCOUNT_TEMP_URL_KEY] = temp_url_key if temp_url_key

    request(relative_path, :method => :post, :headers => h)
  end

  # Returns the temporary URL key
  #
  # @return [String]
  #  Key used to sign temporary URLs
  #
  def temp_url_key
    metadata.temp_url_key rescue nil
  end

  def relative_path
    ''
  end
end
