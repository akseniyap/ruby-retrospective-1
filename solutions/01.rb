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

  def subarray_count subarray
    count = 0
    0.upto(size - 1) { |i| count += 1 if subarray == self[i, subarray.size] }
    count
  end

  def occurences_count
    hash = Hash.new(0)
    each { |element| hash[element] += 1 }
    hash
  end
end
