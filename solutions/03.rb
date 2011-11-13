require 'bigdecimal'
require 'bigdecimal/util'

class Product
  PRODUCT_NAME_LIMIT = 40

  MIN_PRICE = 0.01
  MAX_PRICE = 999.99

  attr_reader :name, :price, :promotion

  def initialize(name, price, promotion)
    price = price.to_d

    validate_length_of             name
    validate_belonging_to_interval price

    @name = name
    @price = price
    @promotion = Promotion.create promotion
  end

  def promo?
    !@promotion.kind_of? Promotion::NoPromotion
  end

  private
    def validate_length_of(product)
      error_message = "Name should be at most #{PRODUCT_NAME_LIMIT} symbols"

      raise error_message if product.size > PRODUCT_NAME_LIMIT
    end

    def validate_belonging_to_interval(price)
      error_message = "Price should be in [#{MIN_PRICE}, #{MAX_PRICE}]"

      raise error_message if price < MIN_PRICE or price > MAX_PRICE
    end
end

class Inventory
  attr_reader :stock, :coupons

  def initialize
    @stock = []
    @coupons = []
  end

  def register(name, price, promotion = {})
    validate_uniqueness_of name, @stock

    product = Product.new name, price, promotion
    @stock << product
  end

  def register_coupon(name, options)
    validate_uniqueness_of name, @coupons

    @coupons << Coupon.create(name, options)
  end

  def find(item)
    type, name = item.to_a.first

    type == :product ? container = @stock : container = @coupons

    container.select { |item| item.name == name }.first
  end

  def new_cart
    cart = ShoppingCart.new self
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
    validate_value_of quantity

    @product = product
    @quantity = 0

    increase_quantity quantity
  end

  def increase_quantity(quantity)
    @quantity += quantity
  end

  def price
    @product.price * @quantity
  end

  def discount
    return '0'.to_d unless @product.promo?

    @product.promotion.item_discount @product.price, @quantity
  end

  private
    def validate_value_of(quantity)
      error_message = "Quantity should be positive integer less than 100"
      raise error_message if quantity <= 0 or quantity > QUANTITY_LIMIT
    end
end

class ShoppingCart
  attr_reader :goods, :inventory
  attr_accessor :coupon, :invoice

  def initialize(inventory, invoice = '')
    @inventory = inventory
    @goods = []
    @coupon = Coupon::NoCoupon.new
    @invoice = invoice
  end

  def add(name, quantity = 1)
    validate_registration_of name, @inventory.stock

    item = @goods.select { |item| item.product.name == name }
    if item.empty?
      product = @inventory.find product: name

      @goods << CartItem.new(product, quantity)
    else
      item.first.increase_quantity quantity
    end
  end

  def use(name)
    validate_registration_of name, @inventory.coupons
    validate_claimed_coupon

    @coupon = @inventory.find coupon: name
  end

  def products_price
    @goods.inject(0) { |sum, cart_item| sum += cart_item.price }
  end

  def products_discount
    @goods.inject(0) { |sum, cart_item| sum += cart_item.discount }
  end

  def coupon_discount
    return '0'.to_d if @coupon.nil?

    price = products_price
    discount = products_discount

    @coupon.discount(price - discount)
  end

  def total
    products_price - products_discount - coupon_discount
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
      when :get_one_free then GetOneFree.new options
      when :package      then Package.new *options.first
      when :threshold    then Threshold.new *options.first
      else NoPromotion.new
    end
  end

  class GetOneFree
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

    def item_discount(price, quantity)
      price * free_items(quantity)
    end

    def invoice
      "(buy #{@n_th_free - 1}, get 1 free)"
    end

    private
      def validate_numericallity_of(n_th_free)
        error_message = "The value should be positive integer more than 1"
        raise error_message if n_th_free <= 1 or !n_th_free.kind_of? Integer
      end
  end

  class Package
    attr_reader :size, :discount

    def initialize(size, discount)
      @size = size
      @discount = discount
    end

    def bought_packages(quantity)
      quantity / @size
    end

    def item_discount(price, quantity)
      packs = bought_packages quantity

      packs * @size * price * @discount / 100
    end

    def invoice
      "(get #{@discount}% off for every #{@size})"
    end
  end

  class Threshold
    attr_reader :size, :discount

    def initialize(size, discount)
      @size = size
      @discount = discount
    end

    def discounted_items(quantity)
      (quantity - @size) < 0 ? 0 : (quantity - @size)
    end

    def item_discount(price, quantity)
      discounted = discounted_items quantity

      discounted * price * @discount / 100
    end

    def number_suffix
      suffixes = {1 => 'st', 2 => 'nd', 3 => 'rd'}

      suffix = suffixes[@size % 10] || 'th'
      suffix = 'th' if [11, 12, 13].include? @size

      suffix
    end

    def invoice
      "(#{@discount}% off of every after the #{@size}#{number_suffix})"
    end
  end

  class NoPromotion
    def item_discount(price, quantity)
      0
    end

    def invoice
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
    attr_reader :name, :percent

    def initialize(name, percent)
      @name = name
      @percent = percent
    end

    def discount(price)
      price * @percent / 100
    end

    def invoice
      "Coupon #{@name} - #{@percent}% off"
    end
  end

  class AmountCoupon
    attr_reader :name, :amount

    def initialize(name, amount)
      @name = name
      @amount = amount.to_d
    end

    def discount(price)
      (price - @amount) < 0 ? price : @amount
    end

    def invoice
      "Coupon #{@name} - #{sprintf '%.2f', @amount.to_f} off"
    end
  end

  class NoCoupon
    attr_reader :name

    def discount(order_price)
      0
    end
  end
end

class Invoice
  SEPARATOR = "+------------------------------------------------+----------+\n"
  HEADER    = "| Name                                       qty |    price |\n"
  TOTAL     = "| TOTAL                                          |"

  attr_reader :cart, :invoice

  def initialize(cart)
    @cart = cart
    @invoice = create_invoice
  end

  def print(price)
    sprintf '%.2f', price.to_f
  end

  def invoice_header
    SEPARATOR + HEADER + SEPARATOR
  end

  def invoice_body
    body = ''

    @cart.goods.each do |cart_item|
      body += "| #{cart_item.product.name.ljust 40} #{cart_item.quantity.to_s.rjust 5}" +
              " | #{print(cart_item.price).rjust 8} |\n"
      body += "|   #{cart_item.product.promotion.invoice.ljust 44} | " +
              "#{print(0 - cart_item.discount).rjust 8} |\n" if cart_item.product.promo?
    end

    body
  end

  def invoice_coupon
    coupon = ''

    coupon += "| #{cart.coupon.invoice.ljust 46} | " +
              "#{print(0 - cart.coupon_discount).rjust 8} |\n" unless cart.coupon.kind_of? Coupon::NoCoupon

    coupon
  end

  def invoice_total
    SEPARATOR + TOTAL + "#{sprintf('%.2f', cart.total.to_f).to_s.rjust 9} |\n" + SEPARATOR
  end

  def create_invoice
    invoice_header + invoice_body + invoice_coupon + invoice_total
  end
end
