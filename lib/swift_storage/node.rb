class SwiftStorage::Node

  include SwiftStorage::Utils

  attr_accessor          :parent,
                         :name

  def initialize(parent, name=nil)
    @parent = parent
    @name = name
  end

  def request(*args)
    service.request(*args)
  end

  # Returns the service for this node
  #
  # @return [SwiftStorage::Service]
  #  The service this node is bound to
  #
  def service
    unless defined?(@service)
      p = parent
      while p && !(SwiftStorage::Service === p)
         p = p.parent
      end
      @service = p
    end
    @service
  end

  def get_lines(path, prefix: nil)
    headers = {'Accept' => 'text/plain'}
    response = request(path, :headers => headers, :params => {:prefix => prefix})
    body = response.body
    if body.nil? || body.empty?
      []
    else
      body.lines.map(&:strip)
    end
  end

  def to_s
    "#<#{self.class.name} #{name}>"
  end

  def relative_path
    raise NotImplemented
  end

  def headers
    return @headers if @headers

    response ||= request(relative_path, :method => :head)

    h = {}
    metadata = h[:metadata] = {}
    response.to_hash.each_pair do |k,v|
      if k =~ /^X-#{self.class.header_name}-Meta-?(.+)/i
        k = $1
        t = metadata
      elsif k =~ /^X-#{self.class.header_name}-?(.+)/i
        k = $1
        t = h
      else
        t = h
      end
      k = k.downcase.gsub(/\W/, '_')
      v = v.first if v.respond_to?(:to_ary)
      t[k] = v
    end
    @headers = struct(h)
  end

  def metadata
    @metadata ||= struct(headers.metadata)
  end

  def clear_cache
    @headers = nil
    @metadata = nil
  end

  def exists?
    request(relative_path, :method => :head) && true
  rescue SwiftStorage::Errors::NotFoundError
    false
  end

  def delete
    # We try a few times, as the swift cluster might need time to get ready
    3.times do |i|
      begin
        return request(relative_path, :method => :delete)
      rescue SwiftStorage::Errors::ServerError
        sleep(i**2)
      end
    end
  end

  def delete_if_exists
    delete
  rescue SwiftStorage::Errors::NotFoundError
    false
  end


  private

  def self.header_name
    self.name.split(':').last
  end


  def self.header_attributes(*args)
    args.each do |a|
      define_method(a.to_sym) do
        headers[a]
      end
    end
  end

  def self.parent_node(name)
    define_method(name.to_sym) do
      parent
    end
  end

  def merge_metadata(headers, metadata)
    return if metadata.nil?
    metadata.each do |k,v|
      sanitized_key = k.to_s.gsub(/\W/, '-')
      sanitized_key = sanitized_key.split('-').reject{|o| o.nil? || o.empty?}
      full_key = ['X', self.class.header_name, 'Meta'] + sanitized_key
      full_key = full_key.map(&:capitalize).join('-')
      headers[full_key] = v.to_s
    end
  end

  private
  H = SwiftStorage::Headers

end


