#!/usr/bin/env ruby

require 'rubygems'
require 'json'
require 'date'

#
# The Geoptima Module provides support for the Geoptima Client JSON file format
#
module Geoptima

  SPERDAY = 60*60*24
  MSPERDAY = 1000*60*60*24
  SHORT = 256*256

  class Config
    DEFAULT={:min_datetime => DateTime.parse("2000-01-01"), :max_datetime => DateTime.parse("2030-01-01")}
    def self.config(options={})
      @@options = (@@options || DEFAULT).merge(options)
    end
    def self.options
      @@options ||= DEFAULT
    end
    def self.[](key)
      options[key]
    end
    def self.[]=(key,value)
      options[key] = value
    end
  end

  # The Geoptima::Event class represents and individual record or event
  class Event
    attr_reader :header, :name, :data, :fields, :time, :latitude, :longitude
    def initialize(start,name,header,data)
      @name = name
      @header = header
      @data = data
      @fields = @header.inject({}) do |a,v|
        a[v] = @data[a.length]
        a
      end
      @time = start + (@fields['timeoffset'].to_f / MSPERDAY.to_f)
      @fields.reject!{|k,v| k=~/timeoffset/}
      if @fields['cell_id'].to_i > SHORT
        @fields['cell_id'] = @fields['cell_id'].to_i % SHORT
      end
      puts "Created Event: #{self}" if($debug)
    end
    def utc
      time.new_offset(0)
    end
    def time_key
      utc.strftime("%Y-%m-%d %H:%M:%S.%3N")
    end
    def [](key)
      @fields[key]
    end
    def -(other)
      (self.time - other.time) * SPERDAY
    end
    def closer_than(other,seconds=60)
      (self - other).abs < seconds
    end
    def locate(gps)
      @latitude = gps['latitude']
      @longitude = gps['longitude']
    end
    def locate_if_closer_than(gps,seconds=60)
      locate(gps) if(closer_than(gps,seconds))
    end
    def to_s
      "#{name}[#{time}]: #{@fields.inspect}"
    end
  end

  # The Geoptima::Data is an entire JSON file of events
  class Data
    attr_reader :path, :json, :count
    def initialize(path)
      @path = path
      @json = JSON.parse(File.read(path))
      if $debug
        puts "Read Geoptima: #{geoptima}"
        puts "\tSubscriber: #{subscriber.to_json}"
        puts "\tIMSI: #{imsi}"
        puts "\tIMEI: #{imei}"
        puts "\tStart: #{start}"
      end
    end
    def to_s
      json.to_json[0..100]
    end
    def geoptima
      @geoptima ||= json['geoptima']
    end
    def subscriber
      @subscriber ||= geoptima['subscriber']
    end
    def imsi
      @imsi ||= subscriber['imsi']
    end
    def imei
      @imei ||= subscriber['imei']
    end
    def platform
      @platform ||= subscriber['Platform'] || subscriber['platform']
    end
    def model
      @model ||= subscriber['Model'] || subscriber['model']
    end
    def os
      @os ||= subscriber['OS']
    end
    def start
      @start ||= subscriber['start'] && DateTime.parse(subscriber['start'].gsub(/Asia\/Bangkok/,'GMT+7').gsub(/Mar 17 2044/,'Feb 14 2012'))
    end
    def valid?
      start && start > Data.min_start && start < Data.max_start
    end
    def self.min_start
      @@min_start ||= DateTime.parse("2010-01-01 00:00:00")
    end
    def self.max_start
      @@max_start ||= DateTime.parse("2020-01-01 00:00:00")
    end
    def events
      @events ||= make_events
    end
    def events_names
      events.keys.sort
    end
    def make_hash(name)
      geoptima[name].inject({}) do |a,md|
        key = md.keys[0]
        a[key]=md[key]
        a
      end
    end
    def make_events
      @count = 0
      @events_metadata = make_hash('events-metadata')
      events_data = {}
      geoptima['events'].each do |data|
        events = data['values']
        event_type = data.keys.reject{|k| k=~/values/}[0]
        header = @events_metadata[event_type]
        if header
          events_data[event_type] = (0...data[event_type].to_i).inject([]) do |a,block|
            index = header.length * block
            data = events[index...(index+header.length)]
            if data && data.length == header.length
              @count += 1
              a << Event.new(start,event_type,header,data)
            else
              puts "Invalid '#{event_type}' data block #{block}: #{data.inspect}"
              break a
            end
          end
          if $debug
            puts "Have '#{event_type}' event data:"
            puts "\t#{header.join("\t")}"
            events_data[event_type].each do |d|
              puts "\t#{d.data.join("\t")}"
            end
          end
        else
          puts "No header found for event type: #{event_type}"
        end
      end
      events_data
    end
  end

  class Dataset

    attr_reader :imei, :options

    def initialize(imei,options={})
      @imei = imei
      @data = []
      @options = options
      @time_range = options[:time_range] || Range.new(Config[:min_datetime],Config[:max_datetime])
    end

    def <<(data)
      @sorted = nil
      @data << data
    end

    def file_count
      @data.length
    end

    def imsi
      imsis[0]
    end

    def imsis
      @imsis ||= @data.inject({}) do |a,d|
        a[d.imsi] ||= 0
        a[d.imsi] += d.count.to_i
        a
      end.to_a.sort do |a,b|
        b[1]<=>a[1]
      end.map do |x|
        #puts "Have IMSI: #{x.join('=')}"
        x[0]
      end.compact.uniq
    end

    def platform
      @platform ||= @data.map{|d| d.platform}.compact.uniq[0]
    end

    def model
      @model ||= @data.map{|d| d.model}.compact.uniq[0]
    end

    def os
      @os ||= @data.map{|d| d.os}.compact.uniq[0]
    end

    def first
      merge_events unless @sorted
      @sorted[nil][0]
    end

    def last
      merge_events unless @sorted
      @sorted[nil][-1]
    end

    def length
      sorted.length
    end

    def sorted(event_type=nil)
      merge_events unless @sorted
      unless @sorted[event_type] || event_type.nil?
        @sorted[event_type] = @sorted[nil].reject do |event|
          event.name != event_type
        end
      end
      @sorted[event_type]
    end

    def header(names=nil)
      merge_events unless @sorted
      (names || events_names).map do |name|
        [(s=sorted(name)[0]) && s.header]
      end.flatten
    end

    def events_names
      @data.map{ |v| v.events_names }.flatten.uniq.sort
    end

    def merge_events
      @sorted ||= {}
      unless @sorted[nil]
        event_hash = {}
        events_names.each do |name|
          @data.each do |data|
            (events = data.events[name]) && events.each do |event|
              if @time_range.include?(event.time)
                key = "#{event.time_key} #{name}"
                event_hash[key] = event
              end
            end
          end
        end
        @sorted[nil] = event_hash.keys.sort.map{|k| event_hash[k]}
        locate_events if(options[:locate])
      end
      @sorted
    end

    def locate_events
      prev_gps = nil
      sorted.each do |event|
        if event.name === 'gps'
          prev_gps = event
        elsif prev_gps
          event.locate_if_closer_than(prev_gps,60)
        end
      end
    end

    def to_s
      "IMEI:#{imei}, IMSI:#{imsis.join(',')}, Platform:#{platform}, Model:#{model}, OS:#{os}, Files:#{file_count}, Events:#{sorted.length}"
    end

    def self.make_datasets(files, options={})
      datasets = {}
      files.each do |file|
        geoptima=Geoptima::Data.new(file)
        unless geoptima.valid?
          puts "INVALID: #{geoptima.start}\t#{file}\n\n"
        else
          datasets[geoptima.imei] ||= Geoptima::Dataset.new(geoptima.imei, options)
          datasets[geoptima.imei] << geoptima
        end
      end
      datasets
    end

  end

end

