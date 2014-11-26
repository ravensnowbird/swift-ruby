class SwiftStorage::Container < SwiftStorage::Node

  parent_node          :service


  def relative_path
    name
  end

  header_attributes          :bytes_used,
                             :object_count


  def objects
    @objects ||= SwiftStorage::ObjectCollection.new(self)
  end

  def create
    request(relative_path, :method => :put)
  end

  def write(write_acl: nil, read_acl: nil)
    h = {}
    read_acl = read_acl.join(',') if read_acl.respond_to?(:to_ary)
    write_acl = write_acl.join(',') if write_acl.respond_to?(:to_ary)

    h[H::CONTAINER_READ] = read_acl
    h[H::CONTAINER_WRITE] = write_acl

    request(relative_path, :method => :post, :headers => h)
  end

  def acl
    r = headers.read.split(',') rescue nil
    w = headers.write.split(',') rescue nil
    struct(:read => r, :write => w)
  end


end

