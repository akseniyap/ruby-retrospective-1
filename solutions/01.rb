class Array
  def to_hash
    hash = {}
    each { |key, value| hash[key] = value }
    hash
  end

  def index_by
    hash = {}
    each { |element| hash[yield(element)] = element }
    hash
  end

  def subarray_count(subarray)
    each_cons(subarray.size).count(subarray)
  end

  def occurences_count
    hash = Hash.new(0)
    each { |element| hash[element] += 1 }
    hash
  end
end
