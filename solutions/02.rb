class Song
  attr_reader :name, :artist, :genre, :subgenre, :tags

  def initialize(name, artist, genre, subgenre=nil, tags=[])
    @name, @artist = name, artist
    @genre, @subgenre = genre, subgenre
    @tags = tags
  end

  def add_genre_tags
    tags << genre.downcase
    tags << subgenre.downcase if subgenre
  end

end

class Collection
  attr_reader :catalog

  def initialize(catalog, artist_tags)
    @catalog = []
    catalog.lines do |line|
      song = Song.new(*parse(line))
      song.add_genre_tags
      @catalog << song
    @artist_tags = artist_tags
    # add_artist_tags
    end
  end

  def add_artist_tags
    @artist_tags.each do |artist, tag|
      @catalog.each do |song|
        if song.artist == artist
          song.tags << tag
          song.tags.flatten!
        end
      end
    end
  end

  def find(criteria={})
    res = Marshal.load(Marshal.dump @catalog)

    res.select! { |song| song.name == criteria[:name] } \
    if criteria.has_key? :name

    res.select! { |song| song.artist == criteria[:artist] } \
    if criteria.has_key? :artist

    if criteria.has_key? :tags
      contains, not_contains = group_tags criteria[:tags]
      res.select! { |song| contains.all? { |tag| song.tags.include? tag } }

      res.reject! { |song| not_contains.all? { |tag| song.tags.include? tag } }
    end

    res.select! { |song| criteria[:filter].call(song) } \
    if criteria.has_key? :filter
    res
  end

  private
    def group_tags(tags)
      tags = Array(tags) unless tags.kind_of? Array
      not_contains = tags.select { |tag| tag.include? "!" }
      contains = tags - not_contains

      [contains, not_contains]
    end

    def parse(input)
      data = input.split('.').map(&:strip)
      data[2] = \
      data[2].include?(',') ? data[2].split(',').map(&:strip) : [data[2], nil]
      data.flatten!
      if data.size == 5
        data[4] = \
        data[4].include?(',') ? data[4].split(',').map(&:strip) : [data[4]]
      end
      data
    end
end
