require 'csv'
require 'nokogiri'

class Transactions
  def initialize(trans_filename)
    @transactions = []
    CSV.foreach(trans_filename, headers: true) do |row|
      amount, currency = row['amount'].split
      @transactions << { store: row['store'].to_sym, sku: row['sku'].to_sym,
        amount: amount.to_f, currency: currency.to_sym }
    end
  end
  
  def each(&block)
    @transactions.each(&block)
  end
end

class Rates
  attr_accessor :rates
  
  def initialize(rates_filename)
    @rates = {}
    Nokogiri::XML(File.open(rates_filename)).css('rate').each do |node|
      from = node.css('from').text.to_sym
      value = node.css('conversion').text.to_f
      to = node.css('to').text.to_sym
      rates[from] ||= {from => 1.0}
      rates[from][to] =  value
      rates[to] ||= {to => 1.0}
    end
    calculate_rates
    puts rates
  end
  
  def [](a)
    rates[a]
  end
  
  def calculate_rates
    rates.keys.each do |k|
      rates.keys.each do |i|
        rates.keys.each do |j|
          next if i == j || i == k || j == k
          rates[i][j] = [ rates[i][j] ? rates[i][j] : 9999 , rates[i][k] * rates[k][j] ].min if rates[i][k] and rates[k][j] and not rates[i][j]
        end
      end
    end
  end
  
end

class TransactionCalculator

  def self.output_total_for(transactions, rates, sku=:DM1182, to=:USD, filename="OUTPUT.txt")
    total = 0.0
    conversions = {}
    transactions.each do |transaction|
      next if transaction[:sku] != sku
      from = transaction[:currency]
      total += (transaction[:amount] * rates[from][to] ).round(2)
    end
    File.open(filename, 'w') { |f| f.puts total.round(2) }
  end
  
end

class InternationalTrade
  
  def self.run(trans_filename, rates_filename)
    transactions = Transactions.new(trans_filename)
    rates = Rates.new(rates_filename)
    TransactionCalculator.output_total_for(transactions, rates)
  end
  
end

if $0 == __FILE__
  InternationalTrade.run(ARGV[0], ARGV[1])
else
  describe Transactions do
    it 'should create an output file that matches the sample output file' do
      InternationalTrade.run('TRANS.csv', 'RATES.xml')
      File.read('OUTPUT.txt').should == File.read('SAMPLE_OUTPUT.txt')
    end
  end
end

