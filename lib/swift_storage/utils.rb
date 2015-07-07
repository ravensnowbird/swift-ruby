require 'openssl'

module SwiftStorage::Utils
  include SwiftStorage::Errors

  def hmac(type, key, data)
    digest = OpenSSL::Digest.new(type)
    OpenSSL::HMAC.digest(digest, key, data)
  end

  def sig_to_hex(str)
    Digest.hexencode(str)
  end

  def struct(h)
    return if h.empty?
    Struct.new(*h.keys.map(&:to_sym)).new(*h.values)
  end
end
