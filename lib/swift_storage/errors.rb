module SwiftStorage::Errors

  class AuthError < StandardError
  end

  class NotFoundError < StandardError
  end

  class ServerError < StandardError
  end

end
