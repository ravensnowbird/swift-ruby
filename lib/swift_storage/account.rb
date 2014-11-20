class SwiftStorage::Account < SwiftStorage::Node

  parent_node          :service

  header_prefix 'X-Account'.freeze


end

