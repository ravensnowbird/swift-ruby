module SwiftStorage::Utils

  include SwiftStorage::Errors

  def hmac(type, key, data)
    digest = OpenSSL::Digest.new(type)
    OpenSSL::HMAC.digest(digest, key, data)
  end

  def sig_to_hex(str)
    str.unpack("C*").map { |c|
      c.to_s(16)
    }.map { |h|
      h.size == 1 ? "0#{h}" : h
    }.join
  end

  def struct(h)
    return nil if h.empty?
    Struct.new(*h.keys.map(&:to_sym)).new(*h.values)
  end

end
