#!/usr/bin/env ruby

# useful if being run inside a source code checkout
$: << 'lib'
$: << '../lib'

require 'date'
require 'geoptima'
require 'geoptima/options'

Geoptima::assert_version("0.1.6")

$debug=false

$event_names=[]
$files = []
$print_limit = 10000

$files = Geoptima::Options.process_args do |option|
  option.p {$print = true}
  option.v {$verbose = true}
  option.x {$export = true}
  option.s {$seperate = true}
  option.o {$export_stats = true}
  option.m {$map_headers = true}
  option.a {$combine_all = true}
  option.l {$more_headers = true}
  option.P {$export_prefix = ARGV.shift}
  option.E {$event_names += ARGV.shift.split(/[\,\;\:\.]+/)}
  option.T {$time_range = Geoptima::DateRange.from ARGV.shift}
  option.L {$print_limit = [1,ARGV.shift.to_i].max}
  option.M {$mapfile = ARGV.shift}
end.map do |file|
  File.exist?(file) ? file : puts("No such file: #{file}")
end.compact

class HeaderMap
  attr_reader :prefix, :name, :event
  attr_accessor :columns
  def initialize(prefix,name,event)
    @prefix = prefix
    @name = name
    @event = event
    @columns = []
  end
  def mk_known(header)
    puts "Creating column mappings for headers: #{header}" if($debug)
    @col_indices = {}
    columns.each do |col|
      c = (col[1] && col[1].gsub(/\?/,'')).to_s
      if c.length>0
        @col_indices[c] = header.index(c)
        puts "\tMade column mapping: #{c} --> #{header.index(c)}" if($debug)
      end
    end
  end
  def map_fields(header,fields)
    @scenario_counter ||= 0
    mk_known(header) unless @col_indices
    @columns.map do |column|
      if column[1] =~ /SCENARIO_COUNTER/
        @scenario_counter += 1
      else
        index = @col_indices[column[1]]
        puts "Found mapping #{column} -> #{index} -> #{index && fields[index]}" if($debug)
        index && fields[index]
      end
    end
  end
end

if $mapfile
  $header_maps = []
  current_map = nil
  prefix = $mapfile.split(/\./)[0]
  File.open($mapfile).each do |line|
    line.chomp!
    next if line =~ /^\s*#/
    next if line.length < 2
    if line =~ /^\[(\w+)\]\t(\w+)/
      current_map = HeaderMap.new(prefix,$1,$2)
      $header_maps << current_map
    elsif current_map
      current_map.columns << line.chomp.split(/\t/)[0..1]
    else
      puts "Invalid header map line: #{line}"
    end
  end
end

def show_header_maps
  if $header_maps
    puts "Using #{$header_maps.length} header maps:"
    $header_maps.each do |hm|
      puts "\t[#{hm.name}] (#{hm.event})"
      if $debug
        hm.columns.each do |hc|
          puts "\t\t#{hc.map{|c| (c+' '*30)[0..30]}.join("\t-->\t")}"
        end
      else
        puts "\t\t#{hm.columns.map{|hc| hc[0]}.join(', ')}"
      end
    end
  end
end

$help = true if($files.length < 1)
if $help
  puts <<EOHELP
Usage: show_geoptima <-dpvxomlsah> <-L limit> <-E types> <-T min,max> <-M mapfile> file <files>
  -d  debug mode (output more context during processing) #{cw $debug}
  -p  print mode (print out final results to console) #{cw $print}
  -v  verbose mode (output extra information to console) #{cw $verbose}
  -x  export IMEI specific CSV files for further processing #{cw $export}
  -o  export field statistis #{cw $export_stats}
  -m  map headers to classic NetView compatible version #{cw $map_headers}
  -l  longer header list (phone and operator fields) #{cw $more_headers}
  -s  seperate the export files by event type #{cw $seperate}
  -a  combine all IMEI's into a single dataset #{cw $combine_all}
  -f  flush stdout #{cw $flush_stdout}
  -h  show this help
  -P  prefix for exported files (default: ''; current: #{$export_prefix})
  -E  comma-seperated list of event types to show and export (default: all; current: #{$event_names.join(',')})
  -T  time range to limit results to (default: all; current: #{$time_range})
  -L  limit verbose output to specific number of lines #{cw $print_limit}
  -M  mapfile of normal->altered header names: #{$mapfile}
EOHELP
  show_header_maps
  exit 0
end

$verbose = $verbose || $debug
show_header_maps if($verbose)

$datasets = Geoptima::Dataset.make_datasets($files, :locate => true, :time_range => $time_range, :combine_all => $combine_all)

class Export
  attr_reader :files, :imei, :names, :headers
  def initialize(imei,names,dataset)
    imei = dataset.imsi if(imei.to_s.length < 1)
    @imei = imei
    @names = names
    if $export
      if $header_maps
        @files = $header_maps.inject({}) do |a,hm|
          a[hm.event] = File.open("#{$export_prefix}#{imei}_#{hm.prefix}_#{hm.name}.csv",'w')
          a
        end
      elsif $seperate
        @files = names.inject({}) do |a,name|
          a[name] = File.open("#{$export_prefix}#{imei}_#{name}.csv",'w')
          a
        end
      else
        @files={nil => File.open("#{$export_prefix}#{imei}.csv",'w')}
      end
    end
    @headers = names.inject({}) do |a,name|
      a[name] = dataset.header([name]).reject{|h| h === 'timeoffset'}
      a[name] = a[name].map{|h| "#{name}.#{h}"} unless($separate)
      puts "Created header for name #{name}: #{a[name].join(',')}" if($debug)
      a
    end
    @headers[nil] = @headers.values.flatten.sort
    files && files.each do |key,file|
      if $header_maps
        file.puts $header_maps.find{|hm| hm.event == key}.columns.map{|c| c[0]}.join("\t")
      else
        file.puts map_headers(base_headers+more_headers+header(key)).join("\t")
      end
    end
    if $debug || $verbose
      @headers.each do |name,head|
        puts "Header[#{name}]: #{head.join(',')}"
      end
    end
  end
  def export_imei
    ($combine_all || $more_headers)
  end
  def base_headers
    ['Time','Event','Latitude','Longitude'] + 
    (export_imei ? ['IMEI'] : [])
  end
  def more_headers
    $more_headers ?
    ['IMSI','MSISDN','MCC','MNC','LAC','CI','LAC-CI','RSSI','Platform','Model','OS','Operator','Battery'] :
    []
  end
  def base_fields(event)
    [event.time_key,event.name,event.latitude,event.longitude] +
    (export_imei ? [event.file.imei] : [])
  end
  def more_fields(event,dataset)
    more_headers.map do |h|
      case h
      when 'RSSI'
        dataset.recent(event,'signal.strength')
      when 'LAC'
        dataset.recent(event,'service.lac')
      when 'CI'
        dataset.recent(event,'service.cell_id')
      when 'LAC-CI'
        "#{dataset.recent(event,'service.lac')}-#{dataset.recent(event,'service.cell_id')}"
      when 'MCC'
        event.file[h] || dataset.recent(event,'service.mcc',3600)
      when 'MNC'
        event.file[h] || dataset.recent(event,'service.mnc',3600)
      when 'Battery'
        dataset.recent(event,'batteryState.state',600)
      when 'Operator'
        event.file['carrierName'] || dataset.recent(event,'carrierName',3600)
      when 'IMSI', 'OS', 'Platform', 'IMSI', 'MSISDN', 'Model'
        event.file[h] || dataset.recent(event,h,3600)
      else
        event.file[h]
      end
    end
  end
  def get_field(event,name)
    h=(base_headers+more_headers).grep(/#{name}/)
  end
  def cap(array,sep="")
    array.map do |v|
      "#{v[0..0].upcase}#{v[1..-1]}"
    end.join(sep)
  end
  def map_headers(hnames)
    $map_headers && hnames.map do |h|
        case h
        when 'Time'
          'time'
        when /gps\./
          cap(h.split(/[\._]/),'_').gsub(/gps/i,'GPS')
        when /^(call|signal|data|sms|mms|browser|neighbor)/i
          cap(h.split(/[\._]/),'_').gsub(/Neighbor/,'Neighbour').gsub(/mms/i,'MMS').gsub(/sms/,'SMS')
        when /\./
          cap(h.split(/[\._]/))
        else
          h
        end
    end || hnames
  end
  def export_stats(stats)
    File.open("#{$export_prefix}#{imei}_stats.csv",'w') do |out|
      stats.keys.sort.each do |header|
        out.puts header
        values = stats[header].keys.sort{|a,b| b.to_s<=>a.to_s}
        out.puts values.join("\t")
        out.puts values.map{|v| stats[header][v]}.join("\t")
        out.puts
      end
    end
  end
  def header(name=nil)
    @headers[name]
  end
  def puts_to(line,name)
    name = nil unless($seperate || $header_maps)
    files[name].puts(line) if($export && files[name])
  end
  def puts_to_all(line)
    files && files.each do |key,file|
      file.puts line
    end
  end
  def close
    files && files.each do |key,file|
      file.close
      @files[key] = nil
    end
  end
end

def if_le
  $count ||= 0
  if $print
    if $count < $print_limit
      yield
    elsif $count == $print_limit
      puts " ... "
    end
  end
  $count += 1
end

puts "Found #{$datasets.length} datasets: #{$datasets.values.join('; ')}"

$datasets.keys.sort.each do |imei|
  dataset = $datasets[imei]
  imsi = dataset.imsi
  events = dataset.sorted
  puts if($print)
  puts "Found #{dataset.description}"
  if $verbose
    puts "\tFirst Event: #{dataset.first}"
    puts "\tLast Event:  #{dataset.last}"
  end
  if events && ($print || $export)
    names = $event_names
    names = dataset.events_names if(names.length<1)
    export = Export.new(imei,names,dataset)
    export.export_stats(dataset.stats) if($export_stats)
    if $header_maps && $header_maps.length > 0
      $header_maps.each do |hm|
        puts "Searching for events for header_maps '#{hm.event}'"
        events.each do |event|
          if event.name == hm.event
            header = export.header(event.name)
            fields = header.map{|h| event[h]}
            b_header = export.base_headers + export.more_headers
            b_fields = export.base_fields(event) + export.more_fields(event,dataset)
            all_fields = hm.map_fields(b_header + header, b_fields + fields)
            export.puts_to all_fields.join("\t"), event.name
          end
        end
      end
    else
      events.each do |event|
        names.each do |name|
          if event.name === name
            fields = export.header($seperate ? name : nil).map{|h| event[h]}
            b_fields = export.base_fields(event) + export.more_fields(event,dataset)
            export.puts_to "#{b_fields.join("\t")}\t#{fields.join("\t")}", name
            if_le{puts "#{b_fields.join("\t")}\t#{event.fields.inspect}"}
          end
        end
      end
    end
    export.close
  end
end

