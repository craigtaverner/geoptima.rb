#!/usr/bin/ruby

# useful if being run inside a source code checkout
$: << 'lib'
$: << '../lib'

require 'geoptima/version'
require 'geoptima/options'
require 'fileutils'
require 'geoptima/daterange'

Geoptima::assert_version(">=0.1.6")

$export_dir = '.'
$export_name = 'merged.csv'
$split_by = :days

$files = Geoptima::Options.process_args do |option|
  option.t {$time_split = true}
  option.m {$low_memory = true}
  option.D {$export_dir = ARGV.shift}
  option.N {$export_name = ARGV.shift}
  option.S do
    $split_by = case ARGV.shift.downcase.intern
    when :days ; :days
    else :days
    end
  end
  option.T {$time_range = Geoptima::DateRange.from ARGV.shift}
end

FileUtils.mkdir_p $export_dir

$help = true unless($files.length>0)
if $help
  puts <<EOHELP
Usage: csv_merge <-dhtm> <-N name> <-D dir> <-T range> <-S split_by> files...
 -d  debug mode #{cw $debug}
 -h  print this help #{cw $help}
 -t  merge and split by time (#{$split_by}) #{cw $time_split}
 -m  use low memory, temporarily storing to intermediate files #{cw $low_memory}
 -N  use specified name for merged dataset: #{$export_name}
 -D  export to specified directory: #{$export_dir}
 -S  time units to split exports by: #{$split_by}
 -T  set time-range filter: #{$time_range}
Files to import: #{$files.join(', ')}
EOHELP
  exit
end

class CSVRecord
  attr_reader :time, :fields, :day
  def initialize(fields,time_index=0)
    @fields = fields
    @time = DateTime.parse(fields[time_index])
    @day = @time.strftime("%Y-%m-%d")
  end
  def [](index)
    fields[index]
  end
  def <=>(other)
    time <=> other
  end
  def within(time_range)
    time_range.nil? || time_range.include?(time)
  end
end

class CSVDataset
  attr_reader :filename, :headers, :day_map, :lines, :count, :record_creation_duration
  def initialize(filename)
    @filename = filename
    @lines = []
    @day_map = {}
    @record_creation_duration = 0
    @count = 0
    @headers = nil
    read_file do |fields|
      add fields
    end
  end
  def read_file
    lines = 0
    File.open(filename).each do |line|
      fields=line.chomp.split(/\t/)
      if lines > 0
        puts "Processing line: #{line}" if($debug)
        yield fields
      else
        if fields.length<2
          puts "Too few headers, rejecting #{file}"
          break
        end
        @headers ||= fields
      end
      lines += 1
    end
    @export_headers ||= @headers
  end
  def add(fields)
    start_time = Time.new
    line = create_line(fields)
    if line
      @day_map[line.day] ||= 0
      @day_map[line.day] += 1
      @lines << line unless($low_memory)
      @count += 1
      @record_creation_duration += Time.new - start_time
    end
    line
  end
  def create_line(fields)
    begin
      line = CSVRecord.new(fields,0)
      if(line.within($time_range))
        line
      else
        nil
      end
    rescue ArgumentError
      puts "Failed to parse line with timestamp='#{fields[0]}': #{$!}"
    end
  end
  def header_map(eh=nil)
    if eh
      @export_headers = eh
      @header_map = nil
    end
    unless @header_map
      @header_map = []
      (@export_headers || @headers).each do |head|
        @header_map << @headers.index(head)
      end
    end
    @header_map
  end
  def map_line(line)
    @header_map.map do |index|
      index && line[index]
    end
  end
  def days
    @day_map.keys.sort
  end
  def each(eh=nil)
    header_map(eh)
    if $low_memory
      read_file do |fields|
        line = create_line fields
        yield line.day,map_line(line)
      end
    else
      (@lines || []).each do |line|
        yield line.day,map_line(line)
      end
    end
  end
  def <=>(other)
    self.filename <=> other.filename
  end
  def length
    count
  end
end

class CSVDatasets
  attr_reader :datasets
  def initialize
    @datasets = []
  end
  def add_file(file)
    lines = 0
    dataset = nil
    filename = File.basename(file)
    (names = filename.split(/[_\.]/)).pop
    name = names.join('_')
    puts "About to read file #{file}"
    dataset = CSVDataset.new(file)
    @datasets << dataset if(dataset && dataset.length>0)
    dataset
  end
  def export_days
    headers = @datasets.map{|d| d.headers}.flatten.uniq
    days = @datasets.map{|d| d.days}.flatten.sort.uniq
    day_files = {}
    day_names = {}
    count = {}
    duration = {}
    days.each do |day|
      filename = "#{$export_dir}/#{$export_name.gsub(/\.csv$/,'')}_#{day}.csv"
      puts "Exporting #{filename} for #{day}"
      day_names[day] = filename
      day_files[day] = File.open(filename,'w')
      day_files[day].puts headers.join("\t")
      count[day] = 0
      duration[day] = 0
    end
    @datasets.sort.each do |dataset|
      dataset.each(headers) do |day,line|
        start_time = Time.new
        day_files[day].puts line.join("\t")
        duration[day] += Time.new - start_time
        count[day] += 1
      end
    end
    day_files.each do |day,out|
      out.close
      puts "\tExported #{count[day]} records to #{day_names[day]} in #{duration[day]} seconds"
    end
  end
  def export_merged
    headers = @datasets.map{|d| d.headers}.flatten.sort.uniq
    filename = "#{$export_dir}/#{$export_name}"
    File.open(filename,'w') do |out|
      out.puts headers.join("\t")
      @datasets.sort.each do |dataset|
        dataset.each(headers) do |day,line|
          out.puts line.join("\t")
        end
      end
    end
  end
end

$datasets = CSVDatasets.new

$files.each do |file|
  start_time = Time.new
  ds = $datasets.add_file(file)
  duration = Time.new - start_time
  puts "\tLoaded #{file} in #{duration} seconds"
  puts "\t#{(100.0 * ds.record_creation_duration.to_f/duration.to_f).to_i}% = #{ds.record_creation_duration}/#{duration} was spent creating records"
  puts "\tFile contained #{ds.length} events for #{ds.days.length} days:"
  ds.days.each do |day|
    puts "\t\t#{day}: \t#{(100.0 * ds.day_map[day].to_f/ds.length.to_f).to_i}%\t#{ds.day_map[day]} records"
  end
end

start_time = Time.new

if $time_split
  $datasets.export_days
else
  $datasets.export_merged
end

duration = Time.new - start_time
puts "Exported in #{duration} seconds"

