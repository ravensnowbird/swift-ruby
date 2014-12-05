class SwiftStorage::ContainerCollection < SwiftStorage::Node

  parent_node          :service


  # Return all containers
  #
  # @note This method will return only the first 1000 containers.
  #
  # @return [Array<SwiftStorage::Container>]
  #  Containers in this collection.
  #
  def all
    get_lines('').map { |name| SwiftStorage::Container.new(service, name)}
  end

  # Return a particular container
  #
  # @note This always return a container, regadeless of it's existence
  #  on the server. This call do NOT contact the server.
  #
  # @param name [String]
  #  The name (sometimes named key) of the container
  #
  # @return [SwiftStorage::Object]
  #  Container with given name
  #
  def [](name)
    SwiftStorage::Container.new(service, name) if name
  end

end


