#!/usr/bin/env ruby

# useful if being run inside a source code checkout
$: << 'lib'
$: << '../lib'

require 'geoptima/version'
require 'geoptima/file_time'

Geoptima::assert_version(">=0.1.17")

class Stats
  attr_accessor :no_server, :has_server, :count
  def initialize
    @no_server = []
    @has_server = []
    @count = 0
  end

  def process_file(path)
    return unless(path =~ /\.json$/i)
    filetime = JSONFileTime.new(File.basename path)
    @count += 1
    if filetime.has_server?
      @has_server << filetime
    else
      @no_server << filetime
    end
  end

  def process_path(path)
    puts "Processing path: #{path}" if($debug)
    if File.directory? path
      process_dir(path)
    elsif File.exist? path
      process_file path
    else
      puts "No such file or directory: #{path}" if($debug)
    end
  end

  def process_dir(dir)
    Dir.open(dir).each do |file|
      next if(file =~ /^\./)
      process_path "#{dir}/#{file}"
    end
  end

  def report(out)
    puts "Loaded #{count} files:"
    puts "\t#{no_server.length} without server timestamp"
    puts "\t#{has_server.length} with server timestamp"
    stats = {}
    has_server.each do |file|
      key = file.correction.to_i
      stats[key] ||= 0
      stats[key] += 1
    end
    stats.keys.sort.each do |key|
      puts "\t\t#{key}:\t#{stats[key]}"
    end
  end

end

class JSONFileTime
  attr_accessor :name, :times, :client_time, :server_time, :correction
  def initialize(name)
    @name = name
    @times = Geoptima::FileTime.from_file name
    @client_time = @times[0]
    if @times.length > 1
      puts "\tCalculating times for #{name}: #{@times.join(', ')}" if($debug)
      @server_time = @times[1]
      puts "\t\tClient: #{t2s client_time}" if($debug)
      puts "\t\tServer: #{t2s server_time}" if($debug)
      @correction = (@server_time - @client_time) * Geoptima::FileTime::DAY_SECONDS
      puts "\t\tTime offset: #{@correction}" if($debug)
    end
  end
  def t2s(time)
    time.new_offset(0).strftime("%Y-%m-%d %H:%M:%S.%3N").gsub(/\.(\d{3})\d+/,'.\1')
  end
  def has_server?
    @server_time
  end
  def to_s
    "#{name}:#{client_time}"
  end
  def row
    "#{(name.to_s+" "*40)[0..40]} -->   #{times.join(', ')}"
  end
end

stats = Stats.new
$paths = []

while arg = ARGV.shift
  if arg =~ /^[\-\+]+(\w+)/
    $1.split(//).each do |aa|
      case aa
      when 'd'
        $debug = true
      when 'h'
        $help = true
      else
        puts "Unknown option: -#{aa}"
      end
    end
  else
    $paths << arg
  end
end

$help = true if($paths.length < 1)

if $help
  puts <<EOHELP
usage: geoptima_file_time_stats <-dh> path <paths..>
  -d  Debug mode
  -h  Print help and exit
Each path can be a file or directory. When a directory is selected, a recursive
search for files is done. Only files with .json extension are processed.
EOHELP
  exit 0
end

$paths.each do |path|
  stats.process_path(path)
end

stats.report(STDOUT)

