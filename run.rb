require "rubygems"
require "active_record"
require "yaml"

class BenchBase
  def connect(cnf)
    %w{adapter username password}.each { |k| raise "The cnf don't have #{k} key." unless cnf.has_key?(k) }
    ::ActiveRecord::Base.establish_connection(cnf)
  end

  def create_table(table_info)
    table_info.each do |table_name, columns|
      ActiveRecord::Migration.create_table table_name.to_sym, :force => true do |t|
        columns.each do |col_name, type|
          t.column col_name.to_sym, type.to_sym
        end
      end
    end
  end

  def initialize(table_info)
    connection_data = YAML.load_file("db_config.yaml")
    raise "db_config.yaml don't have 'connection' key." unless connection_data.kind_of?(Hash) and connection_data.has_key?("connection")
    connect(connection_data['connection'])
    create_table(table_info)
  end

  # mainを実行し、その実行時間を得る
  #TODO試行回数のうまい変数名はないものか?
  def run(count_for_mean, all_num)
    results = []
    puts LABELS.join(",") if Kernel.const_defined?("LABELS")
    all_num.times do |j|
      params = prepare || {}
      count_for_mean.times do |i|
        # 実行
        start_time = Time.now
        main(params)
        end_time = Time.now

        # 結果出力
        output(j, i, start_time, end_time, params)
        results << [i, start_time, end_time]
      end
    end
    results
  end
end

class ExtraColumnBenchmark < BenchBase

  # 使用するテーブル
  class Record < ActiveRecord::Base; end
  class SecondRecord < ActiveRecord::Base; end

  def prepare
    garbage_byte = rand(1000) # 0-999のうちランダムなサイズのゴミを入れる
    Record.destroy_all
    SecondRecord.destroy_all
    100.times do |i|
      Record.create!(:int=>i, :str=>"*"*garbage_byte + i.to_s)
      SecondRecord.create!(:int=>i, :str=>"*"*garbage_byte + i.to_s)
    end
    ActiveRecord::Base.connection.execute("OPTIMIZE TABLE records");
    ActiveRecord::Base.connection.execute("OPTIMIZE TABLE second_records");
    {:garbage_byte => garbage_byte}
  end

  def main(params)
    table_size = params[:table_size]
    garbage_byte = params[:garbage_byte]
    3.times do
      Record.find_by_int(rand(table_size))
      SecondRecord.find_by_int(rand(table_size))
    end
  end

  LABELS = %w{index seconds garbage_byte}
  def output(index1, index2, start_time, end_time, params)
    diff_time = end_time - start_time
    puts "#{index1}, #{index2}, #{diff_time}, #{params[:garbage_byte]}"
  end
end

b = ExtraColumnBenchmark.new(:second_records => {:int => :integer, :str => :text}, :records => {:int => :integer, :str => :text})
b.run(3, 30)
