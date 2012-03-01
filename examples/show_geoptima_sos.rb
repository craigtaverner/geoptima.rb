#!/usr/bin/env ruby

# useful if being run inside a source code checkout
$: << 'lib'
$: << '../lib'

require 'date'
require 'geoptima'

$debug=false

$events={}
$files = []

$events={}

while arg=ARGV.shift:
  if arg =~ /^\-(\w+)/
    $1.split(//).each do |aa|
      case aa
      when 'd'
        $debug=true
      else
        puts "Unrecognized option: -#{aa}"
      end
    end
  else
    if File.exist? arg
      $files << arg
    else
      puts "No such file: #{arg}"
    end
  end
end

$datasets = Geoptima::Dataset.make_datasets($files, :locate => true)

puts "Found #{$datasets.length} IMEIs"
$datasets.keys.sort.each do |imei|
  dataset = $datasets[imei]
  events = dataset.sorted('mode')
  puts "\nFor #{imei} found #{dataset.length} events:\n"
  if events && events.length>0
    puts "Time\tLat\tLon\t#{events.first.header[1..-1].join("\t")}"
    events.each do |event|
      puts "#{event.time}\t#{event.latitude}\t#{event.longitude}\t#{event.data[1..-1].join("\t")}"
    end
  end
end

