class SwiftStorage::Container < SwiftStorage::Node

  parent_node          :service


  def relative_path
    name
  end

  header_attributes          :bytes_used,
                             :object_count


  # Returns the object collection for this container
  #
  # @return [SwiftStorage::ObjectCollection]
  #  The object collection.
  #
  def objects
    @objects ||= SwiftStorage::ObjectCollection.new(self)
  end

  # Create the container
  #
  def create
    request(relative_path, :method => :put)
  end

  # Write the container meta data
  #
  # @note This overrides all ACL set on the container.
  #
  # Each ACL is a string in the following format:
  #
  # - `team:jon` give access to user "jon" of account "team"
  #
  # @param read_acl [Array<String>]
  #  An array of ACL.
  #
  # @param write_acl [Array<String>]
  #  An array of ACL.
  #
  def write(write_acl: nil, read_acl: nil)
    h = {}
    read_acl = read_acl.join(',') if read_acl.respond_to?(:to_ary)
    write_acl = write_acl.join(',') if write_acl.respond_to?(:to_ary)

    h[H::CONTAINER_READ] = read_acl
    h[H::CONTAINER_WRITE] = write_acl

    request(relative_path, :method => :post, :headers => h)
  end

  # Read the container meta data
  #
  # @return [Struct]
  #  A struct with `read` and `write` ACL, each entry contains an Array of
  #  String.
  def acl
    r = headers.read.split(',') rescue nil
    w = headers.write.split(',') rescue nil
    struct(:read => r, :write => w)
  end


end

