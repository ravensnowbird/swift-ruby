class SwiftStorage::Node

  include SwiftStorage::Utils

  attr_accessor          :parent,
                         :name,
                         :options

  def initialize(parent, name=nil, options={})
    @parent = parent
    @name = name
    @options = options
  end

  def request(*args)
    parent.request(*args)
  end

  def service
    unless defined?(@service)
      p = parent
      while !(SwiftStorage::Service === p)
         p = p.parent
      end
      @service = p
    end
    @service
  end

  def get_json(path)
    headers = {'Accept' => 'application/json'}
    response = request(path, :headers => headers)
    Oj.load(response.body)
  end

  def get_lines(path)
    headers = {'Accept' => 'text/plain'}
    response = request(path, :headers => headers)
    response.body.lines.map(&:strip)
  end

  def to_s
    "#<#{self.class.name} #{name}>"
  end

  def relative_path
    raise NotImplemented
  end

  def headers
    unless defined?(@headers)
      response = request(relative_path, :method => :head)

      m = {}
      response.to_hash.each_pair do |k,v|
        if k =~ /^#{self.class.header_prefix}-?(.+)/i
          k = $1
        end
        k = k.downcase.gsub('-', '_')
        m[k] = v
      end
      @headers = struct(m)
    end
    @headers
  end

  private
  def struct(h)
    return nil if h.empty?
    Struct.new(*h.keys.map(&:to_sym)).new(*h.values)
  end

  def self.header_prefix(prefix=nil)
    @header_prefix = prefix if prefix
    @header_prefix
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

end


