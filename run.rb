require "rubygems"
require "active_record"

# === helpers ============================
def output(t, label)
  puts "#{label}, #{t.strftime("%H%M%S")}.#{t.usec}"
end
# ========================================

# TODO: YAMLから読み込むように書き換える
ActiveRecord::Base.establish_connection(
  :adapter => 'mysql',
  :username => 'root',
  :password => '',
  :socket => '/tmp/mysql.sock',
  :database => 'experiment',
  :encoding => 'utf8'
)

class Record < ActiveRecord::Base; end
class SecondRecord < ActiveRecord::Base; end

class CreateRecordTable < ActiveRecord::Migration
  drop_table :records if Record.table_exists?
  create_table :records do |t|
    t.integer :int
    t.text :str
  end
  #add_index :records, :int

  drop_table :second_records if SecondRecord.table_exists?
  create_table :second_records do |t|
    t.integer :int
    t.text :str
  end
  #add_index :second_records, :int
end

#==========================
# table_size個のレコードをRecord, SecondRecordに挿入する
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

def output_label
  puts "index, seconds, garbage_byte"
end

def run_benchmark(table_size, count, garbage_size)
  count.times do |i|
    start_time = Time.now
    3.times do
      Record.find_by_int(rand(table_size))
      SecondRecord.find_by_int(rand(table_size))
    end
    end_time = Time.now
    puts "#{i},#{end_time - start_time}, #{garbage_size}"
  end
end

TABLE_SIZE = 10000
MAX_GRABAGE_SIZE = 10000

output_label
30.times do |j|
  STDERR.print "."
  garbage_byte = rand(MAX_GRABAGE_SIZE)
  prepare_records(TABLE_SIZE, garbage_byte)
  run_benchmark(TABLE_SIZE, 10, garbage_byte)
end
