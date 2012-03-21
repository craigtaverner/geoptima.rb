#!/usr/bin/ruby

# useful if being run inside a source code checkout
$: << 'lib'
$: << '../lib'

require 'geoptima/chart'
require 'geoptima/version'
require 'geoptima/options'
require 'fileutils'

Geoptima::assert_version("0.0.9")

$export_dir = '.'
$diversity = 40.0

$files = Geoptima::Options.process_args do |option|
  option.m {$merge_all = true}
  option.a {$create_all = true}
  option.D {$export_dir = ARGV.shift}
  option.N {$merged_name = ARGV.shift}
  option.S {$specfile = ARGV.shift}
  option.P {$diversity = ARGV.shift.to_f}
end

FileUtils.mkdir_p $export_dir

$help = true unless($files.length>0)
if $help
  puts <<EOHELP
Usage: csv_chart <-dham> <-S specfile> <-N name> <-D dir> files...
 -d  debug mode #{cw $debug}
 -h  print this help #{cw $help}
 -a  automatically create charts for all properties #{cw $create_all}
 -m  merge all files into single stats #{cw $merge_all}
 -N  use specified name for merged dataset: #{$merged_name}
 -D  export charts to specified directory: #{$export_dir}
 -S  use chart specification in specified file: #{$specfile}
 -P  diversity threshold in percentage for automatic reports: #{$diversity}
Files to import: #{$files.join(', ')}
EOHELP
  exit
end

class Stats
  attr_reader :file, :name, :headers, :stats, :data
  def initialize(file,name,fields)
    @file = file
    @name = name
    @headers = fields
    @stats = fields.map{|h| {}}
    @data = fields.map{|h| []}
    @numerical = fields.map{|h| true}
  end
  def add_header(h)
    @headers << h
    @stats << {}
    @data << []
    @numerical << true
    @headers.length - 1
  end
  def add(field,index)
    puts "\tAdding field '#{field}' at index #{index}" if($debug)
    if field && field =~ /\w/
      @numerical[index] &&= is_number?(field)
      puts "\tField[#{index}]: #{field}" if($debug)
      stats = @stats[index]
      stats[field] ||= 0
      stats[field] += 1
      puts "\tField[#{index}]: #{field} => #{stats[field]}" if($debug)
      @data[index] << field
    end
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
  def length(index)
    @stats[index].length
  end
  def diversity(index)
    100.0 * @stats[index].length.to_f / @data[index].length.to_f
  end
  def diverse?(index)
    @stats[index].length>500 || diversity(index) > $diversity
  end
  def numerical?(index)
    @numerical[index]
  end
end

$stats = {}

module Geoptima
  class StatSpec
    attr_reader :header, :index, :indices, :fields, :options, :proc
    def initialize(header,*fields,&block)
      @header = header
      @fields = fields
      @proc = block
      if @fields[-1].is_a?(Hash)
        @options = @fields.pop
      else
        @options = {}
      end
      puts "Created StatSpec: #{self}"
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
    def map(values)
      if @indices
        puts "StatSpec[#{self}]: #{options.inspect}" if($debug)
        vals = @indices.map{|i| values[i]}
        if options[:div]
          vals.map!{|v| mk_range(v)}
        end
        puts "StatSpec[#{self}]: #{vals.inspect}" if($debug)
        val = proc.call(*vals)
        puts "StatSpec[#{self}]: #{vals.inspect} --> #{val.inspect}" if($debug)
        val
      end
    end
    def prepare_indices(stats)
      if stats.headers.index(header)
        puts "Header '#{header}' already exists, cannot create #{self}"
      else
        @index = stats.add_header(header)
        @indices = @fields.map{|h| stats.headers.index(h) || stats.headers.index(h.downcase) }
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
    def initialize(chart_type,header,options={})
      @header = header
      @chart_type = chart_type
      @options = options
    end
    def process(stats)
      puts "Charting #{header} using stats.headers: #{stats.headers}"
      index = stats.headers.index(header)
      index ||= stats.headers.index(header.downcase)
      unless index
        puts "Cannot find statistics for '#{header}' - ignoring chart"
        return
      end
      puts "Charting #{header} at index #{index} and options #{options.inspect}"
      puts "Charting #{header} with diversity #{stats.diversity(index)}"
      hist = stats.stats[index]
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
      legend = $merge_all ? "ALL" : stats.name
      g = Geoptima::Chart.send "draw_#{chart_type}_chart", stats.name, keys, values, options
      g.write("#{$export_dir}/Chart_#{stats.name}_#{header}_distribution.png")
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
      chart(:category, header, options)
    end
    def histogram_chart(header,options={})
      chart(:histogram, header, options)
    end
    def line_chart(header,options={})
      chart(:line, header, options)
    end
    def chart(chart_type,header,options={})
      @chart_specs << ChartSpec.new(chart_type,header,options)
    end
    def stats(header,*fields,&block)
      @stat_specs << StatSpec.new(header,*fields,&block)
    end
    def add_stats(stats)
      stat_specs.each do |stat_spec|
        stat_spec.prepare_indices(stats)
      end
    end
    def add_fields(stats,fields)
      $specs.stat_specs.each do |stat_spec|
        stats.add(
          stat_spec.map(fields),
          stat_spec.index
        )
      end
    end
    def to_s
      "Charts[#{chart_specs.length}]: #{@chart_specs.join(', ')}"
    end
  end
end

$specfile && $specs = Geoptima::StatsSpecs.new($specfile)

$files.each do |file|
  lines = 0
  filename = File.basename(file)
  (names = filename.split(/[_\.]/)).pop
  name = $merged_name || names.join('_')
  puts "About to read file #{file}"
  File.open(file).each do |line|
    lines += 1
    fields=line.chomp.split(/\t/)
    if $stats[file]
      puts "Processing line: #{line}" if($debug)
      fields.each_with_index do |field,index|
        $stats[file].add(field,index)
      end
      $specs && $specs.add_fields($stats[file],fields)
    elsif($merge_all && $stats.length>0)
      file = $stats.values[0].file
    else
      $stats[file] = Stats.new(filename,name,fields)
      $specs && $specs.add_stats($stats[file])
    end
  end
end

$stats.each do |file,stats|
  if $specs
    $specs.chart_specs.each do |chart_spec|
      chart_spec.process(stats)
    end
  else
  stats.headers.each_with_index do |header,index|
    puts "Charting #{header} with diversity #{stats.diversity(index)}"
    case header
    when 'signal.strength'
      Geoptima::Chart.draw_line_chart(
        stats.name,
        stats.data[0],
        stats.data[index].map{|f| v=f.to_i; (v>-130 && v<0) ? v : nil},
        :title => 'Signal Strength',
        :maximum_value => -30,
        :minimum_value => -130,
        :width => 1024
      ).write("#{$export_dir}/Chart_#{stats.name}_#{header}.png")

      hist = stats.stats[index]
      keys = hist.keys.sort{|a,b| a.to_i <=> b.to_i}
      values = keys.map{|k| hist[k]}
      Geoptima::Chart.draw_histogram_chart(
        stats.name, keys, values,
        :title => 'Signal Strength Distribution',
        :width => 1024
      ).write("#{$export_dir}/Chart_#{stats.name}_#{header}_distribution.png")

    when 'Event'
      hist = stats.stats[index]
      keys = hist.keys.sort{|a,b| a.to_i <=> b.to_i}
      values = keys.map{|k| hist[k]}
      Geoptima::Chart.draw_category_chart(
        stats.name, keys, values,
        :title => "#{header} Distribution",
        :width => 1024
      ).write("#{$export_dir}/Chart_#{stats.name}_#{header}_distribution.png")

    else
      if stats.diverse?(index)
        puts "Ignoring high diversity field #{header}"
      else
        puts "Charting field: #{header} with length #{stats.length(index)} and diversity #{stats.diversity(index)}"
        hist = stats.stats[index]
        keys = hist.keys.sort{|a,b| a.to_i <=> b.to_i}
        values = keys.map{|k| hist[k]}
        args = [stats.name, keys, values, {
          :title => "#{header} Distribution",
          :width => 1024}]
        g = (stats.length(index) > 50) ?
              Geoptima::Chart.draw_line_chart(*args) :
            (stats.length(index) > 10 || stats.numerical?(index)) ?
              Geoptima::Chart.draw_histogram_chart(*args) :
            (stats.length(index) > 1) ?
              Geoptima::Chart.draw_category_chart(*args) :
            nil
        g && g.write("#{$export_dir}/Chart_#{stats.name}_#{header}_distribution.png")
      end
    end
  end
  end
end

