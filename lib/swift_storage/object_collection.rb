class SwiftStorage::ObjectCollection < SwiftStorage::Node

  parent_node          :container


  def all
    get_lines(container.name).map { |name| SwiftStorage::Object.new(container, name)}
  end

  def [](name)
    SwiftStorage::Object.new(container, name)
  end


end



