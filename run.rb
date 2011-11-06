require "rubygems"
require "active_record"
require "yaml"

# === helpers ============================
def output(label, t)
  puts "#{label}, #{t.strftime("%H%M%S")}.#{t.usec}"
end
# ========================================

class ExtraColumnBenchmark
  TABLE_SIZE = 100
  MAX_GRABAGE_SIZE = 100

  # DB準備系 ===============
  class Record < ActiveRecord::Base; end
  class SecondRecord < ActiveRecord::Base; end

  def connect(cnf)
    %w{adapter username password}.each { |k| raise "The cnf don't have #{k} key." unless cnf.has_key?(k) }
    ::ActiveRecord::Base.establish_connection(cnf)
  end

  def create_table
    ActiveRecord::Migration.drop_table :records if Record.table_exists?
    ActiveRecord::Migration.create_table :records do |t|
      t.integer :int
      t.text :str
    end
    #add_index :records, :int

    ActiveRecord::Migration.drop_table :second_records if SecondRecord.table_exists?
    ActiveRecord::Migration.create_table :second_records do |t|
      t.integer :int
      t.text :str
    end
  end

  def prepare_records(table_size, garbage_size)
    Record.destroy_all
    SecondRecord.destroy_all
    table_size.times do |i|
      Record.create!(:int=>i, :str=>"*"*garbage_size + i.to_s)
      SecondRecord.create!(:int=>i, :str=>"*"*garbage_size + i.to_s)
    end
    ActiveRecord::Base.connection.execute("OPTIMIZE TABLE records");
    ActiveRecord::Base.connection.execute("OPTIMIZE TABLE second_records");
  end

  def initialize
    connection_data = YAML.load_file("db_config.yaml")
    raise "db_config.yaml don't have 'connection' key." unless connection_data.kind_of?(Hash) and connection_data.has_key?("connection")
    connect(connection_data['connection'])
    create_table
  end

  def run(block)
    results = []
    puts "index, seconds, garbage_byte"
    30.times do |j|
      STDERR.print "."
      garbage_byte = rand(MAX_GRABAGE_SIZE)
      prepare_records(TABLE_SIZE, garbage_byte)
      2.times do |i|
        start_time, end_time = run_benchmark(TABLE_SIZE, garbage_byte)
        block.call(i, start_time, end_time) if block
        results << [i, start_time, end_time]
      end
    end

    puts "run was called."
    results
  end

  private
  def run_benchmark(table_size, garbage_size)
    start_time = Time.now
    3.times do
      Record.find_by_int(rand(table_size))
      SecondRecord.find_by_int(rand(table_size))
    end
    end_time = Time.now
    return start_time, end_time
  end
end

b = ExtraColumnBenchmark.new
b.run(lambda{|index, start_time, end_time|
  diff_time = end_time - start_time
  puts "#{index}, #{diff_time}"
})
