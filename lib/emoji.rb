class Emoji
  def initialize(name, url)
    @name = name
    @url = url
  end

  def name
    @name
  end

  def url
    @url
  end

  def filename
    @url.split('/').last
  end

  def extension
    @url.split('.').last
  end

  def alias_target_name
    url.split(':').last
  end

  def alias?
    @url.start_with?('alias')
  end

  def ==(other)
    self.name == other.name
  end
end
