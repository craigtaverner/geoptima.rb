#!/usr/bin/ruby

# useful if being run inside a source code checkout
$: << 'lib'
$: << '../lib'

require 'geoptima/chart'
require 'geoptima/options'
require 'fileutils'

$export_dir = '.'

$files = Geoptima::Options.process_args do |option|
  option.m {$merge_all = true}
  option.D {$export_dir = ARGV.shift}
  option.N {$merged_name = ARGV.shift}
end

FileUtils.mkdir_p $export_dir

$help = true unless($files.length>0)
if $help
  puts <<EOHELP
Usage: csv_chart <-dhm> <-N name> <-D dir> files...
 -d  debug mode #{cw $debug}
 -h  print this help #{cw $help}
 -m  merge all files into single stats #{cw $merge_all}
 -N  use specified name for merged dataset: #{$merged_name}
 -D  export charts to specified directory: #{$export_dir}
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
  def add(field,index)
    if field =~ /\w/
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
    @stats[index].length>500 || diversity(index) > 40.0
  end
  def numerical?(index)
    @numerical[index]
  end
end

$stats = {}

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
    elsif($merge_all && $stats.length>0)
      file = $stats.values[0].file
    else
      $stats[file] = Stats.new(filename,name,fields)
    end
  end
end

$stats.each do |file,stats|
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
        puts "Ingnoring high diversity field #{header}"
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

