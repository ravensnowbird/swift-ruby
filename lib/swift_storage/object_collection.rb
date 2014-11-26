class SwiftStorage::ObjectCollection < SwiftStorage::Node

  parent_node          :container


  # Return all objects
  #
  # @note This method will return only the first 1000 objects.
  #
  # @return [Array<SwiftStorage::Object>]
  #  Objects in this collection
  #
  def all
    get_lines(container.name).map { |name| SwiftStorage::Object.new(container, name)}
  end

  # Return a particular object
  #
  # @note This always return an object, regadeless of it's existence
  #  on the server. This call do NOT contact the server.
  #
  # @param name [String]
  #  The name (sometimes named key) of the object
  #
  # @return [SwiftStorage::Object]
  #  Object with given name
  #
  def [](name)
    SwiftStorage::Object.new(container, name)
  end

end


