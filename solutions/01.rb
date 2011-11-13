class Array
  def to_hash
    hash = {}
    each { |element| hash[element[0]] = element[1] }
    hash
  end

  def index_by &block
    hash = {}
    each { |element| hash[block.call(element)] = element }
    hash
  end

  def subarray_count subarray
    return -1 if subarray == [] || size < subarray.size

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
