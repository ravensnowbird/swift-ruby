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

end

