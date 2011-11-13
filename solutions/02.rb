class Song
  attr_reader :name, :artist, :genre, :subgenre, :tags

  def initialize(name, artist, genres, tags)
    @name, @artist    = name, artist
    @genre, @subgenre = *genres
    @tags             = tags
  end

  def matches?(criteria)
    criteria.all? do |method_name, value|
      method = 'matches_' + method_name.to_s + '?'
      send method, value
    end
  end

  private
    def matches_name?(song_name)
      @name == song_name
    end

    def matches_artist?(song_artist)
      @artist == song_artist
    end

    def matches_filter?(filter_block)
      filter_block.call(self)
    end

    def matches_tags?(tags)
      tags = [*tags]

      exclude_tags = tags.select { |tag| tag.end_with? '!' }
      include_tags = tags - exclude_tags

      include_tags.all? { |tag| @tags.include? tag } and
        exclude_tags.none? { |tag| @tags.include? tag.chomp('!') }
    end
end

class Collection
  def initialize(songs, artist_tags)
    @catalog = []
    @artist_tags = artist_tags

    songs.lines do |song|
      song_properties = parse song
      add_geners_tags song_properties
      add_artist_tags song_properties

      @catalog << Song.new(*song_properties.values)
    end
  end

  def parse(line)
    properties = [:name, :artist, :geners, :tags]
    values = line.split('.').map(&:strip)

    options = to_hash(properties.zip(values))
    options[:tags] ||= ""

    [:geners, :tags].each do |property|
      options[property] = options[property].split(',').map(&:strip)
    end
    options
  end

  def find(criteria = {})
    @catalog.select { |song| song.matches? criteria }
  end

  private
    def add_geners_tags options
      options[:tags] += options[:geners].map(&:downcase)
    end

    def add_artist_tags options
      options[:tags] += @artist_tags.fetch(options[:artist], [])
    end

    def to_hash(array)
      hash = {}
      array.each { |key, value| hash[key] = value }
      hash
    end
end
