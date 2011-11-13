require 'bigdecimal'
require 'bigdecimal/util'

class Product
  PRODUCT_NAME_LIMIT = 40

  MIN_PRICE = 0.01
  MAX_PRICE = 999.99

  attr_reader :name, :price, :promotion

  def initialize(name, price, promotion)
    price = price.to_d

    validate_length_of name
    validate_value_of  price

    @name      = name
    @price     = price
    @promotion = Promotion.create promotion
  end

  private
    def validate_length_of(name)
      error_message = "Name should be at most #{PRODUCT_NAME_LIMIT} symbols"

      raise error_message if name.size > PRODUCT_NAME_LIMIT
    end

    def validate_value_of(price)
      error_message = "Price should be in [#{MIN_PRICE}, #{MAX_PRICE}]"

      raise error_message if price < MIN_PRICE or price > MAX_PRICE
    end
end

class Inventory
  attr_reader :stock, :coupons

  def initialize
    @stock   = []
    @coupons = []
  end

  def register(name, price, promotion = {})
    validate_uniqueness_of name, @stock

    @stock << Product.new(name, price, promotion)
  end

  def register_coupon(name, options)
    validate_uniqueness_of name, @coupons

    @coupons << Coupon.create(name, options)
  end

  def find(item)
    type, name = item.to_a.first
    container = type == :product ? @stock : @coupons

    container.detect { |item| item.name == name } or raise "No #{type} #{name}"
  end

  def new_cart
    ShoppingCart.new self
  end

  private
    def validate_uniqueness_of(item, container)
      error_message = "#{item} is already registered"
      registered = container.map(&:name).map(&:downcase)

      raise error_message if registered.include? item.downcase
    end
end

class CartItem
  QUANTITY_LIMIT = 99

  attr_reader :product
  attr_accessor :quantity

  def initialize(product, quantity)
    @product  = product
    @quantity = 0

    increase_quantity quantity
  end

  def increase_quantity(quantity)
    validate_value_of @quantity + quantity

    @quantity += quantity
  end

  def price
    @product.price * @quantity
  end

  def discount
    @product.promotion.discount @product.price, @quantity
  end

  def promotional?
    not discount.zero?
  end

  private
    def validate_value_of(quantity)
      error_message = "Quantity should be positive integer less than 100"

      raise error_message if quantity <= 0 or quantity > QUANTITY_LIMIT
    end
end

class ShoppingCart
  attr_reader :goods, :coupon

  def initialize(inventory)
    @inventory = inventory
    @goods     = []
    @coupon    = Coupon::NoCoupon.new
    @invoice   = ''
  end

  def add(name, quantity = 1)
    validate_registration_of name, @inventory.stock

    item = @goods.detect { |item| item.product.name == name }
    if item
      item.increase_quantity quantity
    else
      product = @inventory.find product: name

      @goods << CartItem.new(product, quantity)
    end
  end

  def use(name)
    validate_registration_of name, @inventory.coupons
    validate_claimed_coupon

    @coupon = @inventory.find coupon: name
  end

  def price_for
    price = {}
    price[:purchases] = @goods.map(&:price).inject(:+)
    price[:discounts] = @goods.map(&:discount).inject(:+)
    price[:coupon]    = @coupon.discount(price[:purchases] - price[:discounts])
    price
  end

  def total
    price_for[:purchases] - price_for[:discounts] - price_for[:coupon]
  end

  def invoice
    @invoice = (Invoice.new self).invoice
  end

  private
    def validate_registration_of(item, container)
      error_message = "#{item} is not registered"
      registered = container.map(&:name).map(&:downcase)

      raise error_message unless registered.include? item.downcase
    end

    def validate_claimed_coupon
      error_message = "You alredy claimed to use #{coupon}"

      raise error_message unless @coupon.kind_of? Coupon::NoCoupon
    end
end

module Promotion
  def self.create(hash)
    name, options = hash.first

    case name
      when :get_one_free then GetOneFreePromotion.new options
      when :package      then PackagePromotion.new *options.first
      when :threshold    then ThresholdPromotion.new *options.first
      else NoPromotion.new
    end
  end

  class GetOneFreePromotion
    attr_reader :n_th_free

    def initialize(n_th_free)
      validate_numericallity_of n_th_free

      @n_th_free = n_th_free
    end

    def free_items(quantity)
      quantity / @n_th_free
    end

    def paid_items(quantity)
      quantity - free_items(quantity)
    end

    def discount(price, quantity)
      price * free_items(quantity)
    end

    def description
      "  (buy #{@n_th_free - 1}, get 1 free)"
    end

    private
      def validate_numericallity_of(n_th_free)
        error_message = "The value should be positive integer more than 1"

        raise error_message if n_th_free <= 1 or not n_th_free.kind_of? Integer
      end
  end

  class PackagePromotion
    attr_reader :size, :percent

    def initialize(size, percent)
      @size    = size
      @percent = percent
    end

    def bought_packages(quantity)
      quantity / @size
    end

    def discount(price, quantity)
      packs = bought_packages quantity

      packs * @size * price * @percent / '100'.to_d
    end

    def description
      "  (get #{@percent}% off for every #{@size})"
    end
  end

  class ThresholdPromotion
    attr_reader :threshold, :percent

    def initialize(threshold, percent)
      @threshold = threshold
      @percent   = percent
    end

    def discounted_items(quantity)
      quantity < @threshold ? 0 : (quantity - @threshold)
    end

    def discount(price, quantity)
      discounted = discounted_items quantity

      discounted * price * @percent / '100'.to_d
    end

    def suffix
      {1 => 'st', 2 => 'nd', 3 => 'rd'}.fetch @threshold, 'th'
    end

    def description
      "  (#{@percent}% off of every after the #{@threshold}#{suffix})"
    end
  end

  class NoPromotion
    def discount(price, quantity)
      0
    end

    def description
      ''
    end
  end
end

module Coupon
  def self.create(name, hash)
    type, value = hash.to_a.first

    case type
      when :percent then PercentCoupon.new(name, value)
      when :amount  then AmountCoupon.new(name, value)
      else NoCoupon.new
    end
  end

  class PercentCoupon
    attr_reader :name

    def initialize(name, percent)
      @name    = name
      @percent = percent
    end

    def discount(price)
      price * @percent / '100'.to_d
    end

    def description
      "Coupon #{@name} - #{@percent}% off"
    end
  end

  class AmountCoupon
    attr_reader :name

    def initialize(name, amount)
      @name   = name
      @amount = amount.to_d
    end

    def discount(price)
      price < @amount ? price : @amount
    end

    def description
      "Coupon #{@name} - #{"%5.2f" % @amount} off"
    end
  end

  class NoCoupon
    def discount(order_price)
      0
    end

    def description
      ''
    end
  end
end

class Invoice
  SEPARATOR = "+#{'-' * 48}+#{'-' * 10}+\n"

  attr_reader :cart, :invoice

  def initialize(cart)
    @cart    = cart
    @invoice = ''

    @invoice = create_invoice
  end

  def invoice_header
    print_separator
    print 'Name', 'qty', 'price'
    print_separator
  end

  def invoice_middle
    @cart.goods.each do |item|
      print item.product.name, item.quantity, amount(item.price)
      print item.product.promotion.description, '', amount(-item.discount)
    end

    print @cart.coupon.description, '', amount(-@cart.price_for[:coupon])
  end

  def invoice_total
    print_separator
    print 'TOTAL', '', amount(@cart.total)
    print_separator
  end

  def create_invoice
    invoice_header
    invoice_middle
    invoice_total
  end

  def amount(decimal)
    "%5.2f" % decimal
  end

  def print_separator
    @invoice << SEPARATOR
  end

  def print(*args)
    @invoice << "| %-40s %5s | %8s |\n" % args unless args.first.strip == ''
  end
end
