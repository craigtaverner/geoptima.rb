#!/usr/bin/ruby

require 'rubygems'

$chart_libs = ['gruff'].map do |chart_lib|
  begin
    require chart_lib
    chart_lib
  rescue LoadError
    puts "Failed to load charting library '#{chart_lib}': #{$!}"
  end
end.compact

if $chart_libs.length > 0
  puts "Loaded #{$chart_libs.length} charting libraries: #{$chart_libs.join(', ')}"
else
  puts "Warning: No charting libraries loaded. Chart support disabled."
  puts "Please consider installing appropriate chart gems like 'gruff'"
end

module Geoptima
  class Chart
    def self.libs
      $chart_libs
    end
    def self.available?
      $chart_libs.length>0
    end
    DEFAULT_OPTIONS = {:show_points => true, :show_lines => true, :title => nil, :width => 800, :margins => 20, :font_size => 14}
    attr_reader :chart_type
    attr_accessor :chart, :data, :options
    def initialize(chart_type,options={})
      @chart_type = chart_type
      @options = DEFAULT_OPTIONS.merge(options)
    end
    def self.engine
      @@engine ||= $chart_libs[0] || 'not available'
    end
    def self.engine=(name)
      @@engine = $chart_libs.grep(/name/)[0] || engine
    end
    def self.line(options={})
      make_chart(:line,options)
    end
    def self.draw_line_chart(legend,keys,values,options={})
      g = make_chart(:line,{:show_points => false}.merge(options))
      g.data(legend, values)
      g.labels= {0=>keys[0].to_s, (keys.length-1)=>keys[-1].to_s}
      options[:maximum_value] && g.maximum_value = options[:maximum_value].to_i
      options[:minimum_value] && g.minimum_value = options[:minimum_value].to_i
      options[:filename] && g.write(options[:filename])
      g
    end
    def self.draw_histogram_chart(legend,keys,values,options={})
      puts "Creating a chart with legend #{legend} for #{keys.length} keys and #{values.length} values"
      chart_type = options[:side] ? :side_bar : :bar
      g = make_chart(chart_type, options)
      g.data(legend, values)
      g.minimum_value = 0
      mod = 1
      unless options[:side]
        while(keys.length/mod > 10) do
          mod+=1
        end
      end
      labels = {}
      keys.each_with_index{|v,i| labels[i] = v.to_s if(i%mod == 0)}
      g.labels = labels
      options[:filename] && g.write(options[:filename])
      g
    end
    def self.draw_grouped_chart(legends,keys,values,options={})
      puts "Creating a chart with legends #{legends.inspect} for #{keys.length} keys"
      chart_type = (options[:chart_type]==:line) ? :line : :bar
      g = make_chart(chart_type, options)
      legends.each do |legend|
        g.data(legend, values[legend])
      end
      g.minimum_value = 0
      g.labels = keys.inject({}){|a,v| a[a.length] = v.to_s;a}
      options[:filename] && g.write(options[:filename])
      g
    end
    def self.draw_category_chart(legend,keys,values,options={})
      puts "Creating category chart with keys: #{keys.join(',')}"
      puts "Creating category chart with values: #{values.join(',')}"
      g = make_chart(:bar, options)
      keys.each_with_index do |key,index|
        puts "\t Adding category #{key} with value #{values[index]}"
        g.data(key, values[index])
      end
      g.minimum_value = 0
      options[:filename] && g.write(options[:filename])
      g
    end
    def self.bar(options={})
      make_chart(:bar,options)
    end
    def self.make_chart(chart_type,options={})
      case engine
      when 'gruff'
        GruffChart.new(chart_type,options)
      else
        puts "Unsupported chart engine: #{@@engine}"
      end
    end
  end
  class GruffChart < Chart
    def initialize(chart_type,options={})
      super(chart_type,options)
    end
    def chart
      unless @chart
        case chart_type.to_s
        when 'line'
          @chart = Gruff::Line.new(options[:width])
          @chart.hide_dots = !options[:show_points]
          @chart.hide_lines = !options[:show_lines]
        when 'bar'
          @chart = Gruff::Bar.new(options[:width])
        when 'side_bar'
          @chart = Gruff::SideBar.new(options[:width])
        else
          raise "Unsupported chart type: #{chart_type}"
        end
        @chart.title = options[:title]
        @chart.margins = options[:margins]
        @chart.legend_font_size = options[:font_size]
        @chart.marker_font_size = options[:font_size]
        @chart.title_font_size = options[:title_font_size] || 2 * options[:font_size]
      end
      @chart
    end
    def data(name,values)
      chart.data(name,values)
    end
    def labels=(label_map)
      chart.labels = label_map
    end
    def method_missing(symbol,*args,&block)
      chart.send symbol, *args, &block
    end
    def write(filename)
      chart.write(filename)
    end
  end
end

