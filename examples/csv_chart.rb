#!/usr/bin/ruby

# useful if being run inside a source code checkout
$: << 'lib'
$: << '../lib'

require 'geoptima/chart'
require 'geoptima/version'
require 'geoptima/options'
require 'fileutils'
require 'geoptima/daterange'

Geoptima::assert_version("0.1.1")
Geoptima::Chart.available? || puts("No charting libraries available") || exit(-1)

$export_dir = '.'
$diversity = 40.0

$files = Geoptima::Options.process_args do |option|
  option.m {$merge_all = true}
  option.a {$create_all = true}
  option.t {$time_split = true}
  option.D {$export_dir = ARGV.shift}
  option.N {$merged_name = ARGV.shift}
  option.S {$specfile = ARGV.shift}
  option.P {$diversity = ARGV.shift.to_f}
  option.T do
    $time_range = Geoptima::DateRange.new(*(ARGV.shift.split(/[\,]+/).map do |t|
      DateTime.parse t
    end))
  end
end

FileUtils.mkdir_p $export_dir

$create_all = true unless($specfile)
$merge_all = true if($time_split)
$help = true unless($files.length>0)
if $help
  puts <<EOHELP
Usage: csv_chart <-dhamt> <-S specfile> <-N name> <-D dir> <-T range> <-P diversity> files...
 -d  debug mode #{cw $debug}
 -h  print this help #{cw $help}
 -a  automatically create charts for all properties #{cw $create_all}
 -m  merge all files into single stats #{cw $merge_all}
 -t  merge and split by time (days) #{cw $time_split}
 -N  use specified name for merged dataset: #{$merged_name}
 -D  export charts to specified directory: #{$export_dir}
 -S  use chart specification in specified file: #{$specfile}
 -P  diversity threshold in percentage for automatic reports: #{$diversity}
 -T  set time-range filter: #{$time_range}
Files to import: #{$files.join(', ')}
EOHELP
  exit
end

class Stats
  attr_reader :name, :stats, :data, :numerical
  def initialize(name)
    @name = name
    @stats = {}
    @data = []
    @numerical = true
  end
  def add(field)
    puts "\tAdding field '#{field}' for property #{name}" if($debug)
    if field && field =~ /\w/
      @numerical &&= is_number?(field)
      stats[field] ||= 0
      stats[field] += 1
      @data << field
    end
  end
  def length
    @stats.length
  end
  def numerical?
    @numerical
  end
  def diversity
    100.0 * @stats.length.to_f / @data.length.to_f
  end
  def diverse?
    @stats.length>500 || diversity > $diversity
  end
  def is_number?(field)
    is_integer?(field) || is_float?(field)
  end
  def is_integer?(field)
    field.to_i.to_s == field
  end
  def is_float?(field)
    field.to_f.to_s == field
  end
  def to_s
    "#{name}[#{length}]"
  end
end

class StatsManager
  attr_reader :name, :headers, :stats
  def initialize(name)
    @name = name
    @headers = []
    @stats = {}
  end
  def time_index
    @time_index ||= @headers.index('Time') || @headers.index('Timestamp')
  end
  def time_stats
    @time_stats ||= get_stats('Time') || get_stats('Timestamp')
  end
  def set_headers(headers)
    @headers = []
    headers.each {|h| add_header(h)}
    $specs && $specs.add_stats(self,headers)
  end
  def add_header(h)
    if @headers.index(h)
      puts "Stats header already exists: #{h}"
    else
      @headers << h
      @stats[h] ||= Stats.new(h)
    end
    @headers.index(h)
  end
  def get_stats(header)
    stats[header] || stats[header.downcase]
  end
  def add_all(fields,headers)
    fields.each_with_index do |field,index|
      add(field,headers[index])
    end
    $specs && $specs.add_fields(self,fields)
  end
  def add(field,header)
    puts "\tAdding field '#{field}' for property #{header}" if($debug)
    add_header(header) unless(@stats[header])
    @stats[header].add(field)
  end
  def length
    @stats.length
  end
  def to_s
    "Stats[#{length}]: #{@stats.inspect}"
  end
end

module Geoptima
  class StatSpec
    attr_reader :header, :index, :indices, :fields, :options, :proc, :groups
    def initialize(header,*fields,&block)
      @header = header
      @fields = fields
      @proc = block
      @groups = {}
      if @fields[-1].is_a?(Hash)
        @options = @fields.pop
      else
        @options = {}
      end
      if @options[:group]
        case @options[:group].to_s.intern
        when :months
          group_by {|t| t.strftime("%Y-%m")}
        when :days
          group_by {|t| t.strftime("%Y-%m-%d")}
        else
          group_by {|t| t.strftime("%Y-%m-%d %H")}
        end
      end
      puts "Created StatSpec: #{self}"
    end
    def group_by(&block)
      @group = block
    end
    def add(stats_manager,fields)
      if @group
        begin
          time = DateTime.parse(fields[stats_manager.time_index])
          if $time_range.nil? || $time_range.include?(time)
            key = @group.call(time)
            ghead = "#{header} #{key}"
            @groups[key] = ghead
            stats_manager.add(map(fields),ghead)
          end
        rescue ArgumentError
          puts "Error: Unable to process time field[#{time}]: #{$!}"
        end
      end
      stats_manager.add(map(fields),header)
    end
    def mk_range(val)
      if val =~ /\w/
        div = options[:div].to_i
        div = 1 if(div<1)
        min = val.to_i/div * div
        "#{min}..#{min+div}"
      else
        val
      end
    end
    def map(values,filter=nil)
      if @indices
        puts "StatSpec[#{self}]: #{options.inspect}" if($debug)
        vals = @indices.map{|i| values[i]}
        if options[:div]
          vals.map!{|v| mk_range(v)}
        end
        puts "StatSpec[#{self}]: #{vals.inspect}" if($debug)
        val = proc && proc.call(*vals) || vals[0]
        puts "StatSpec[#{self}]: #{vals.inspect} --> #{val.inspect}" if($debug)
        val
      end
    end
    def prepare_indices(stats_manager,headers)
      if headers.index(header)
        puts "Header '#{header}' already exists, cannot create #{self}"
        @index = nil
        @indices = nil
      else
        @index = stats_manager.add_header(header)
        @indices = @fields.map{|h| headers.index(h) || headers.index(h.downcase) }
        puts "#{self}: Header[#{@index}], Indices[#{@indices.join(',')}]" if($debug)
        if @indices.compact.length < @fields.length
          puts "Unable to find some headers for #{self}, ignoring stats"
          @indices = nil
        end
      end
    end
    def to_s
      "#{header}[#{index}]<-#{fields.inspect}(#{indices && indices.join(',')})"
    end
  end
  class ChartSpec
    attr_reader :chart_type, :header, :options
    def initialize(header,options={})
      @header = header
      @chart_type = options[:chart_type] || :histogram
      @options = options
    end
    def process(stats_manager)
      puts "Charting #{header} using headers: #{stats_manager.headers.inspect}"
      stat_spec = $specs.stat_specs.find{|o| o.header == header}
      stats = stats_manager.get_stats(header)
      grouped_stats = {}
      if stat_spec
        stat_spec.groups.each do |name,header|
          gs = stats_manager.get_stats(header)
          grouped_stats[name] = gs
          stats ||= gs
        end
      end
      unless stats
        puts "Cannot find statistics for '#{header}' - ignoring chart"
        return
      end
      puts "Charting #{header} with options #{options.inspect} and stats: #{stats}"
      puts "Charting #{header} with diversity #{stats.diversity}"
      if grouped_stats.length > 0
        title = options[:title]
        title ||= "#{header} Distribution"
        options.merge!( :title => title, :width => 1024 )
        value_map = {}
        groups = grouped_stats.keys.sort
        groups.each_with_index do |name,index|
          gs = grouped_stats[name]
          hist = gs.stats
          hist.keys.each do |k|
            value_map[k] ||= [].fill(0,0...groups.length)
            value_map[k][index] = hist[k]
          end
        end
        legends = value_map.keys.sort
        g = Geoptima::Chart.draw_grouped_chart legends, groups, value_map, options
      else
        hist = stats.stats
        title = options[:title]
        if options[:top]
          keys = hist.keys.sort{|a,b| hist[b] <=> hist[a]}[0..(options[:top].to_i)]
          title ||= "#{header} Top #{options[:top]}"
        else
          keys = hist.keys.sort{|a,b| a.to_i <=> b.to_i}
        end
        values = keys.map{|k| hist[k]}
        title ||= "#{header} Distribution"
        options.merge!( :title => title, :width => 1024 )
        g = Geoptima::Chart.send "draw_#{chart_type}_chart", stats_manager.name, keys, values, options
      end
      g.write("#{$export_dir}/Chart_#{stats_manager.name}_#{header}_#{chart_type}_distribution.png")
    end
    def to_s
      "#{chart_type.upcase}-#{header}"
    end
  end
  class StatsSpecs
    attr_reader :chart_specs, :stat_specs
    def initialize(specfile)
      @chart_specs = []
      @stat_specs = []
      instance_eval(File.open(specfile).read)
    end
    def category_chart(header,options={})
      chart(header, options.merge(:chart_type => :category))
    end
    def histogram_chart(header,options={})
      chart(header, options.merge(:chart_type => :histogram))
    end
    def line_chart(header,options={})
      chart(header, options.merge(:chart_type => :line))
    end
    def chart(header,options={})
      @chart_specs << ChartSpec.new(header,options)
    end
    def stats(header,*fields,&block)
      @stat_specs << StatSpec.new(header,*fields,&block)
    end
    def add_stats(stats_manager,headers)
      stat_specs.each do |stat_spec|
        stat_spec.prepare_indices(stats_manager,headers)
      end
    end
    def add_fields(stats_manager,fields)
      stat_specs.each do |stat_spec|
        stat_spec.add(stats_manager,fields)
      end
    end
    def to_s
      "Stats[#{@stat_specs.join(', ')}] AND Charts[#{@chart_specs.join(', ')}]"
    end
  end
end

def create_all(name,stats_manager)
  stats_manager.headers.each do |header|
    stats = stats_manager.stats[header]
    puts "Charting #{header} with diversity #{stats.diversity}"
    case header
    when 'signal.strength'
      Geoptima::Chart.draw_line_chart(
        stats_manager.name,
        stats_manager.time_stats.data,
        stats.data.map{|f| v=f.to_i; (v>-130 && v<0) ? v : nil},
        :title => 'Signal Strength',
        :maximum_value => -30,
        :minimum_value => -130,
        :width => 1024
      ).write("#{$export_dir}/Chart_#{stats_manager.name}_#{header}.png")

      hist = stats.stats
      keys = hist.keys.sort{|a,b| a.to_i <=> b.to_i}
      values = keys.map{|k| hist[k]}
      Geoptima::Chart.draw_histogram_chart(
        stats_manager.name, keys, values,
        :title => 'Signal Strength Distribution',
        :width => 1024
      ).write("#{$export_dir}/Chart_#{stats_manager.name}_#{header}_distribution.png")

    when 'Event'
      hist = stats.stats
      keys = hist.keys.sort{|a,b| a.to_i <=> b.to_i}
      values = keys.map{|k| hist[k]}
      Geoptima::Chart.draw_category_chart(
        stats_manager.name, keys, values,
        :title => "#{header} Distribution",
        :width => 1024
      ).write("#{$export_dir}/Chart_#{stats_manager.name}_#{header}_distribution.png")

    else
      if stats.diverse?
        puts "Ignoring high diversity field #{header}"
      else
        puts "Charting field: #{header} with length #{stats.length} and diversity #{stats.diversity}"
        hist = stats.stats
        keys = hist.keys.sort{|a,b| a.to_i <=> b.to_i}
        values = keys.map{|k| hist[k]}
        args = [stats_manager.name, keys, values, {
          :title => "#{header} Distribution",
          :width => 1024}]
        g = (stats.length > 50) ?
              Geoptima::Chart.draw_line_chart(*args) :
            (stats.length > 10 || stats.numerical?) ?
              Geoptima::Chart.draw_histogram_chart(*args) :
            (stats.length > 1) ?
              Geoptima::Chart.draw_category_chart(*args) :
            nil
        g && g.write("#{$export_dir}/Chart_#{stats_manager.name}_#{header}_distribution.png")
      end
    end
  end
end

#
# Now run the actual program, reading the specifation file and then the CSV files
#

$stats_managers = {}

$specfile && $specs = Geoptima::StatsSpecs.new($specfile)

$files.each do |file|
  lines = 0
  headers = nil
  filename = File.basename(file)
  (names = filename.split(/[_\.]/)).pop
  name = $merge_all ? ($merged_name || 'All') : names.join('_')
  $stats_managers[name] ||= StatsManager.new(name)
  puts "About to read file #{file}"
  File.open(file).each do |line|
    lines += 1
    fields=line.chomp.split(/\t/)
    if headers
      puts "Processing line: #{line}" if($debug)
      $stats_managers[name].add_all(fields,headers)
    else
      headers = fields
      if headers.length<2
        puts "Too few headers, rejecting #{file}"
        break
      end
      $stats_managers[name].set_headers(headers)
    end
  end
end

# Finally output all charts specified

$stats_managers.each do |name,stats_manager|
  if $specs
    $specs.chart_specs.each do |chart_spec|
      chart_spec.process(stats_manager)
    end
  end
  if $create_all
    create_all name, stats_manager
  end
end

