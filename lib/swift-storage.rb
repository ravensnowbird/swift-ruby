require "net/http"
require "swift_storage/version"
require "swift_storage/configuration"
require "swift_storage/errors"
require "swift_storage/utils"
require "swift_storage/headers"
require "swift_storage/node"
require "swift_storage/account"
require "swift_storage/container"
require "swift_storage/container_collection"
require "swift_storage/object"
require "swift_storage/object_collection"
require "swift_storage/service"

module SwiftStorage
  class << self
    attr_accessor :configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield configuration
  end
end
