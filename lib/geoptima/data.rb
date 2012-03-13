#!/usr/bin/env ruby

require 'rubygems'
require 'multi_json'
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
    KNOWN_HEADERS={
      "gps" => ["timeoffset","latitude","longitude","altitude","accuracy","direction","speed"],
      "service" => ["timeoffset","plmn","cell_id","lac","mnc","mcc"],
      "call" => ["timeoffset","status","number"],
      "runningApps" => ["timeoffset","appName","state"],
      "batteryState" => ["timeoffset","state"],
      "trafficSpeed" => ["timeoffset","interface","direction","delay","speed"],
      "storageStatus" => ["timeoffset","path","totalSize","freeSize"],
      "signal" => ["timeoffset","strength","rxqual","ecio"],
      "roundtrip" => ["timeoffset","interface","address","type","roundtripTime"],
      "httpRequest" => ["timeoffset","interface","address","delay","speed"],
      "dnsLookup" => ["timeoffset","interface","address","lookupTime","ip"],
      "ftpSpeed" => ["timeoffset","interface","direction","delay","peak","speed"],
      "browserDedicatedTest" => ["timeoffset","url","pageRenders","pageRendered","pageSize","success"]
    }
    attr_reader :file, :header, :name, :data, :fields, :time, :latitude, :longitude
    def initialize(file,start,name,header,data)
      @file = file
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
      @fields[key] || @fields[key.gsub(/#{name}\./,'')]
    end
    def []=(key,value)
      @fields[key] ||= value
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
#      @json = JSON.parse(File.read(path))
      @json = MultiJson.decode(File.read(path))
      @fields = {}
      if $debug
        puts "Read Geoptima: #{geoptima.to_json}"
        puts "\tSubscriber: #{subscriber.to_json}"
        puts "\tIMSI: #{self['imsi']}"
        puts "\tIMEI: #{self['imei']}"
        puts "\tMCC: #{self['MCC']}"
        puts "\tMNC: #{self['MNC']}"
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
    def imei
      @imei ||= self['imei']
    end
    def [](key)
      @fields[key] ||= subscriber[key] || subscriber[key.downcase]
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
      puts "About to process json hash: #{geoptima[name].to_json}" if($debug)
      geoptima[name].inject({}) do |a,md|
        if md.respond_to? 'keys'
          key = md.keys[0]
          a[key]=md[key]
        else
          puts "Invalid hash format for '#{name}': #{md.to_json[0..70]}..."
        end
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
        unless header
          puts "No header found for '#{event_type}', trying known Geoptima headers"
          header = Event::KNOWN_HEADERS[event_type]
          if header
            puts "Found known header '#{event_type}' => #{header.inspect}"
            if data = events_data[event_type]
              mismatch = data.length % header.length
              if mismatch != 0
                puts "Known header length #{header.length} incompatible with data length #{events_data[event_type].length}"
                header = nil
              end
            else
              puts "No data found for event type '#{event_type}'"
              header = nil
            end
          end
        end
        if header
          events_data[event_type] = (0...data[event_type].to_i).inject([]) do |a,block|
            index = header.length * block
            data = events[index...(index+header.length)]
            if data && data.length == header.length
              @count += 1
              a << Event.new(self,start,event_type,header,data)
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
      @fields = {}
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
        a[d['imsi']] ||= 0
        a[d['imsi']] += d.count.to_i
        a
      end.to_a.sort do |a,b|
        b[1]<=>a[1]
      end.map do |x|
        #puts "Have IMSI: #{x.join('=')}"
        x[0]
      end.compact.uniq
    end

    def recent(event,key)
      unless event[key]
        puts "Searching for recent values for '#{key}' starting at event #{event}" if($debug)
        ev,prop=key.split(/\./)
        ar=sorted
        puts "\tSearching through #{ar && ar.length} events for event type #{ev} and property #{prop}" if($debug)
        if i=ar.index(event)
          afe = while(i>0)
            fe = ar[i-=1]
            puts "\t\tTesting event[#{i}]: #{fe}" if($debug)
            break(fe) if(fe.nil? || fe.name == ev || (event.time - fe.time) * SPERDAY > 60)
          end
          if afe && afe.name == ev
            puts "\t\tFound event[#{i}] with #{prop} => #{afe[prop]} and time gap of #{(event.time - fe.time) * SPERDAY} seconds" if($verbose)
            event[key] = afe[prop]
          end
        else
          puts "Event not found in search for recent '#{key}': #{event}"
        end
      end
#      @recent[key] ||= ''
      event[key]
    end

    def [](key)
      @fields[key.downcase] ||= @data.map{|d| d[key]}.compact.uniq[0]
    end

    def platform
      self['Platform']
    end

    def model
      self['Model']
    end

    def os
      self['OS']
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

    def stats
      merge_events unless @sorted
      unless @stats
        @stats = {}
        event_count = 0
        sorted.each do |event|
          event_count += 1
          event.header.each do |field|
            key = "#{event.name}.#{field}"
            value = event[field]
            @stats[key] ||= {}
            @stats[key][value] ||= 0
            @stats[key][value] += 1
          end
        end
      end
      @stats.reject! do |k,v|
        v.length > 500 || v.length > 10 && v.length > event_count / 2
      end
      @stats
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
          event.locate(event)
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
          key = options[:combine_all] ? 'all' : geoptima['imei']
          datasets[key] ||= Geoptima::Dataset.new(key, options)
          datasets[key] << geoptima
        end
      end
      datasets
    end

  end

end

