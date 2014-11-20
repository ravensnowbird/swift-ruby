class SwiftStorage::ContainerCollection < SwiftStorage::Node

  parent_node          :service

  def all
    get_lines('').map { |name| SwiftStorage::Container.new(service, name)}
  end

  def [](name)
    SwiftStorage::Container.new(service, name)
  end

end


