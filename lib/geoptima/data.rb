#!/usr/bin/env ruby

require 'rubygems'
require 'multi_json'
require 'geoptima/daterange'
require 'geoptima/locationrange'
begin
  require 'png'
rescue LoadError
  puts "No PNG library installed, ignoring PNG output of GPX results"
end

#
# The Geoptima Module provides support for the Geoptima Client JSON file format
#
module Geoptima

  SPERDAY = 60*60*24
  MSPERDAY = 1000*60*60*24
  SHORT = 256*256
  MIN_VALID_DATETIME = DateTime.parse("1970-01-01")
  MAX_VALID_DATETIME = DateTime.parse("2040-01-01")
  MIN_DATETIME = DateTime.parse("2008-01-01")
  MAX_DATETIME = DateTime.parse("2040-01-01")

  class Config
    DEFAULT={:min_datetime => MIN_DATETIME, :max_datetime => MAX_DATETIME}
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

  class Trace
    attr_reader :dataset, :data_id, :data_ids, :name, :tracename
    attr_reader :bounds, :events, :totals, :scale, :padding
    def initialize(dataset)
      @dataset = dataset
      @data_id = nil
      @data_ids = []
      @name = dataset.name
      @events = []
    end
    def <<(e)
      @tracename ||= "#{name}-#{e.time}"
      unless @data_id
        @data_id ||= e.file.id
        @data_ids << e.file.id
      end
      check_bounds(e)
      check_totals(e)
      @events << e unless(co_located(e,@events[-1]))
    end
    def co_located(event,other)
      event && other && event.latitude == other.latitude && event.longitude == other.longitude
    end
    def length
      events.length
    end
    def to_s
      tracename || name
    end
    def check_totals(e)
      @totals ||= [0.0,0.0,0]
      @totals[0] += e.latitude
      @totals[1] += e.longitude
      @totals[2] += 1
    end
    def check_bounds(e)
      @bounds ||= {}
      check_bounds_min :minlat, e.latitude
      check_bounds_min :minlon, e.longitude
      check_bounds_max :maxlat, e.latitude
      check_bounds_max :maxlon, e.longitude
      @width = nil
      @height = nil
    end
    def check_bounds_min(key,value)
      if value.is_a? String
        raise "Passed a string value: #{value.inspect}"
      end
      begin
        @bounds[key] = value if(@bounds[key].nil? || @bounds[key] > value)
      rescue
         raise "Failed to set bounds using current:#{@bounds.inspect}, value=#{value.inspect}"
      end
    end
    def check_bounds_max(key,value)
      @bounds[key] = value if(@bounds[key].nil? || @bounds[key] < value)
    end
    def each
      events.each{|e| yield e}
    end
    def scale=(a)
      @rescaled = false
      @scale = a && (a.respond_to?('max') ? a : [a.to_i,a.to_i]) || [100,100]
    end
    def padding=(a)
      @padding = a && (a.respond_to?('max') ? a : [a.to_i,a.to_i]) || [0,0]
    end
    def size
      @size = [scale[0]+2*padding[0],scale[1]+2*padding[1]]
    end
    def scale
      @scale ||= [100,100]
      unless @rescaled
        major = [width,height].max
        puts "About to rescale scale=#{@scale.inspect} using major=#{major}, height=#{height}, width=#{width}" if($debug)
        @scale[0] = (@scale[0].to_f * width / major).to_i
        @scale[1] = (@scale[1].to_f * height / major).to_i
        @rescaled = true
      end
      @scale
    end
    def width
      @width ||= @bounds[:maxlon].to_f - @bounds[:minlon].to_f
    end
    def height
      @height ||= @bounds[:maxlat].to_f - @bounds[:minlat].to_f
    end
    def left
      @left ||= @bounds[:minlon].to_f
    end
    def bottom
      @bottom ||= @bounds[:minlat].to_f
    end
    def average
      [totals[0] / totals[2], totals[1] / totals[2]]
    end
    def remove_outliers
      if @bounds && (width > 0.1 || height > 0.1)
        distances = []
        total_distance = 0.0
        max_distance = 0.0
        center = Point.new(*average)
        self.each do |e|
          distance = e.distance_from(center)
          distances << [e,distance]
          total_distance += distance
          max_distance = distance if(max_distance < distance)
        end
        average_distance = total_distance / distances.length
        threshold = max_distance / 3
        if threshold > average_distance * 3
          puts "Average distance #{average_distance} much less than max distance #{max_distance}, trimming all beyond #{threshold}"
          @bounds = {}
          distances.each do |d|
            check_bounds(d[0]) if(d[1] < threshold)
          end
        else
          puts "Average distance #{average_distance} not much less than max distance #{max_distance}, not trimming outliers"
        end
      end
    end
    def scale_event(e)
      p = [e.longitude.to_f, e.latitude.to_f]
      if scale
        p[0] = padding[0] + ((p[0] - left) * (scale[0].to_f - 1) / (width)).to_i
        p[1] = padding[1] + ((p[1] - bottom) * (scale[1].to_f - 1) / (height)).to_i
      end
      p
    end
    def too_far(other)
      events && events[-1] && (events[-1].days_from(other) > 0.5 || events[-1].distance_from(other) > 0.002)
    end
    def bounds_as_gpx
      "<bounds " + bounds.keys.map{|k| "#{k}=\"#{bounds[k]}\""}.join(' ') + "/>"
    end
    def event_as_gpx(e,index)
      "<trkpt lat=\"#{e.latitude}\" lon=\"#{e.longitude}\"><ele>#{index}</ele><time>#{e.time}</time></trkpt>"
    end
    def as_gpx
      ei = 0
      gpx = %{<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="geoptima.rb - Craig Taverner">
  <metadata>
    #{bounds_as_gpx}
  </metadata>
  <trk>
    <name>#{tracename}</name>
    <trkseg>
      } +
      traces.map do |trace|
        trace.events.map do |e|
          ei += 1
          event_as_gpx(e,ei)
        end.join("\n      ")
      end.join("\n      </trkseg><trkseg>") +
      """
    </trkseg>
  </trk>
</gpx>
"""
    end
    def as_csv
      traces.map do |trace|
        trace.events.map do |e|
          [e.time_key,e.latitude,e.longitude].join("\t")
        end.join("\n")
      end.join("\n")
    end
    def fix_options(options={})
      options.keys.each do |key|
        val = options[key]
        if val.to_s =~ /false/i
          val = false
        elsif val != true && val.to_i.to_s == val
          val = val.to_i
        end
        options[key] = val
      end
    end
    def traces
      [self]
    end
    def colors
      @colors ||= PNG::Color.constants.reject{|c| (c.is_a?(PNG::Color)) || c.to_s =~ /max/i || c.to_s =~ /background/i}.map{|c| PNG::Color.const_get c}.reject{|c| c == PNG::Color::Background || c == PNG::Color::Black || c == PNG::Color::White}
    end
    def color(index=1)
      self.colors[index%(self.colors.length)]
    end
    def to_png(filename, options={})
      return unless(length>0)
      fix_options options
      puts "Exporting with options: #{options.inspect}"
      self.scale = options['scale']
      self.padding = options['padding']
      remove_outliers
      ['scale','padding','size','bounds','width','height'].each do |a|
        puts "\t#{a}: #{self.send(a).inspect}"
      end
      begin
        canvas = PNG::Canvas.new size[0],size[1]
      rescue
        puts "Unable to initialize PNG:Canvas - is 'png' gem installed? #{$!}"
        return
      end

      data_idm = data_ids.inject({}){|a,v| a[v]=a.length;a}
      if data_ids.length > 1
        data_ids.each do |did|
          puts "Mapped data ID '#{did}' to color: #{color(data_idm[did])}"
        end
      end
      traces.each_with_index do |trace,index|
        point_color = color(index)
        line_color = PNG::Color.from "0x00006688"
        if options['point_color'] && !(options['point_color'] =~ /auto/i)
          pc = options['point_color'].gsub(/^\#/,'').gsub(/^0x/,'').upcase
          pc = "0x#{pc}FFFFFFFF"[0...10]
          begin
            point_color = PNG::Color.from pc
          rescue
            puts "Failed to interpret color #{pc}, use format 0x00000000: #{$!}"
          end
        elsif data_ids.length > 1
          point_color = color(data_idm[trace.data_id])
          puts "Got point color #{point_color} from data ID '#{trace.data_id}' index #{data_idm[trace.data_id]}" if($debug)
        else
          point_color = color(index)
          puts "Got point color #{point_color} from trace index #{index}" if($debug)
        end

        prev = nil
        trace.events.each do |e|
          p = scale_event(e)
          begin
            # draw an anti-aliased line
            if prev && prev != p
              canvas.line prev[0], prev[1], p[0], p[1], line_color
            end

            if options['points']
              # Set a point to a color
              n = options['point_size'].to_i / 2
              r = (-n..n)
              r.each do |x|
                r.each do |y|
                  canvas[p[0]+x, p[1]-y] = point_color
                end
              end
            end
          rescue
            puts "Error in writing PNG: #{$!}"
          end

          prev = p
        end
      end

      png = PNG.new canvas
      png.save filename
    end
  end

  class MergedTrace < Trace
    attr_reader :traces
    def initialize(dataset)
      @dataset = dataset
      @name = dataset.name
      @data_ids = []
      @traces = []
    end
    def tracename
      @tracename ||= "Merged-#{traces.length}-traces-#{traces[0]}"
    end
    def <<(t)
      check_trace_totals(t)
      check_trace_bounds(t)
      @data_ids = (@data_ids+t.data_ids).sort.uniq.compact
      @traces << t
    end
    def each
      traces.each do |t|
        t.events.each do |e|
          yield e
        end
      end
    end
    def length
      @length ||= traces.inject(0){|a,t| a+=t.length;a}
    end
    def check_trace_totals(t)
      @totals ||= [0.0,0.0,0]
      [0,1,2].each{|i| @totals[i] += t.totals[i]}
    end
    def check_trace_bounds(t)
      @bounds ||= {}
      check_bounds_min :minlat, t.bounds[:minlat]
      check_bounds_min :minlon, t.bounds[:minlon]
      check_bounds_max :maxlat, t.bounds[:maxlat]
      check_bounds_max :maxlon, t.bounds[:maxlon]
      @width = nil
      @height = nil
    end
  end

  module ErrorCounter
    attr_reader :errors
    def errors
      @errors ||= {}
    end
    def incr_error(name)
      errors[name] ||= 0
      errors[name] += 1
    end
    def combine_errors(other)
      puts "Combining errors(#{other.class}:#{other.errors.inspect}) into self(#{self.class}:#{errors.inspect})" if($debug)
      other.errors.keys.each do |name|
        errors[name] = errors[name].to_i + other.errors[name].to_i
      end
    end
    def report_errors(prefix=nil)
      if errors && errors.keys.length > 0
        puts "#{prefix}Have #{errors.keys.length} known errors in #{self}:"
        errors.keys.sort.each do |name|
          puts "#{prefix}\t#{name}:\t#{errors[name]}"
        end
      end
    end
  end

  # The Geoptima::Event class represents and individual record or event
  class Event
    KNOWN_HEADERS = {
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
      "browserDedicatedTest" => ["timeoffset","url","pageRenders","pageRendered","pageSize","success"],
      "pingTest" => ["timeoffset","interface","address","count","length","pingTime","packetLossPercent","jitter","error"]
    }
    HEADER_BUGS = {
      'ftpSpeed' => '#4303',
      'pingTest' => '#4509'
    }
    ALT_HEADERS = {
      "pingTest" => [
        ["timeoffset","interface","address","count","length","pingTime","packetLossPercent","jitter","error"],
        ["timeoffset","id","interface","address","count","length","pingTime","packetLossPercent","jitter","error"]
      ],
      "ftpSpeed" => [
        ["timeoffset","interface","direction","delay","speed"],
        ["timeoffset","interface","direction","delay","peak","speed"],
        ["timeoffset","interface","direction","delay","peak","speed","error"],
        ["timeoffset","interface","direction","delay","peak","speed","size","error"]
      ]
    }

    include ErrorCounter
    attr_reader :file, :header, :name, :data, :fields, :time, :latitude, :longitude, :timeoffset
    def initialize(file,start,name,header,data,previous=nil)
      @file = file
      @name = name
      @header = header
      @data = data
      @fields = @header.inject({}) do |a,v|
        a[v] = check_field(@data[a.length])
        a
      end
      @timeoffset = (@fields['timeoffset'].to_f / MSPERDAY.to_f)
      @time = start + timeoffset # Note we set this again later after corrections (need it now for puts output)
      if(@timeoffset<-0.0000001)
        puts "Have negative time offset: #{@fields['timeoffset']}" if($debug)
        incr_error "#4506 negative offsets"
      end
      if previous
        prev_to = previous.timeoffset
        puts "Comparing timeoffset:#{timeoffset} to previous:#{prev_to}" if($debug)
        if @timeoffset == prev_to
          puts "Found the same timeoffset in consecutive events: #{name}:#{timeoffset} == #{previous.name}:#{previous.timeoffset}"
          incr_error "#4576 same timeoffset"
          @timeoffset = @timeoffset + 1.0 / MSPERDAY.to_f
        end
      end
      @time = start + timeoffset
      @fields.reject!{|k,v| k=~/timeoffset/}
      if @fields['cell_id'].to_i > SHORT
        @fields['cell_id'] = @fields['cell_id'].to_i % SHORT
      end
      incr_error "Empty data" if(data.length == 0)
      puts "Created Event: #{self}" if($debug)
    end
    def check_field(field)
      (field && field.respond_to?('length') && field =~ /\d\,\d/) ? field.gsub(/\,/,'.').to_f : field
    end
    def utc
      time.new_offset(0)
    end
    def time_key
      utc.strftime("%Y-%m-%d %H:%M:%S.%3N").gsub(/\.(\d{3})\d+/,'.\1')
    end
    def days_from(other)
      (other.time - time).abs
    end
    def distance_from(other)
      Math.sqrt((other.latitude.to_f - latitude.to_f)**2 + (other.longitude.to_f - longitude.to_f)**2)
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
    def location
      @location ||= self['latitude'] && Point.new(self['latitude'],self['longitude'])
    end
    def locate(gps)
      incr_error "GPS String Data" if(gps['latitude'].is_a? String)
      @latitude = gps['latitude'].to_f
      @longitude = gps['longitude'].to_f
      @location = nil
    end
    def locate_if_closer_than(gps,seconds=60)
      locate(gps) if(closer_than(gps,seconds))
    end
    def puts line
      Kernel.puts "#{name}[#{time}]: #{line}"
    end
    def to_s
      "#{name}[#{time}]: #{@fields.inspect}"
    end
  end

  # The Geoptima::Data is an entire JSON file of events
  class Data
    include ErrorCounter
    attr_reader :path, :name, :json, :count
    def initialize(path)
      @path = path
      @name = File.basename(path)
#      @json = JSON.parse(File.read(path))
      @json = MultiJson.decode(File.read(path))
      @fields = {}
      @errors = {}
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
    def incr_error(name)
      @errors[name] ||= 0
      @errors[name] += 1
    end
    def to_s
      json.to_json[0..100]
    end
    def puts line
      Kernel.puts "#{name}: #{line}"
    end
    def geoptima
      @geoptima ||= json['geoptima']
    end
    def version
      @version ||= geoptima['Version'] || geoptima['version']
    end
    def subscriber
      @subscriber ||= geoptima['subscriber']
    end
    def imei
      @imei ||= self['imei']
    end
    def id
      @id ||= self['id'] || self['udid'] || self['imei']
    end
    def [](key)
      @fields[key] ||= subscriber[key] || subscriber[key.downcase]
    end
    def start
      @start ||= subscriber['start'] && DateTime.parse(subscriber['start'].gsub(/Asia\/Bangkok/,'GMT+7'))#.gsub(/Mar 17 2044/,'Feb 14 2012'))
    end
    def valid?
      start && start >= (Data.min_start-1) && start < Data.max_start
    end
    def self.min_start
      @@min_start ||= MIN_VALID_DATETIME
    end
    def self.max_start
      @@max_start ||= MAX_VALID_DATETIME
    end
    def events
      @events ||= make_events
    end
    def first
      events && @first
    end
    def last
      events && @last
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
        event_count = data[event_type].to_i
        header = @events_metadata[event_type]
        # If the JSON is broken (known bug on some releases of the iPhone app)
        # Then get the header information from a list of known headers
        unless header
          puts "No header found for '#{event_type}', trying known Geoptima headers"
          header = Event::KNOWN_HEADERS[event_type]
          puts "Found known header '#{event_type}' => #{header.inspect}" if(header)
        end
        # Double-check the header length matches a multiple of the data length
        if header
          mismatch_records = events.length - header.length * event_count
          if mismatch_records != 0
            puts "'#{event_type}' header length #{header.length} incompatible with data length #{events.length} and record count #{event_count}"
            proposed_header = header
            header = nil
            incr_error "Metadata mismatch"
            if events.length == proposed_header.length * event_count * 2 && event_type == 'roundtrip'
              incr_error "#4593 iPhone roundtrip event counts"
              event_count *= 2
              header = proposed_header
            elsif Event::ALT_HEADERS.keys.grep(event_type).length>0
              incr_error "#{Event::HEADER_BUGS[event_type]} #{event_type}"
              [Event::KNOWN_HEADERS[event_type],*(Event::ALT_HEADERS[event_type])].each do |alt_header|
                puts "Trying alternative header: #{alt_header.inspect}" if($debug)
                if alt_header && (events.length == alt_header.length * event_count)
                  puts "\tAlternative header length matches: #{alt_header.inspect}" if($debug)
                  records_valid = (0...[10,event_count].min).inject(true) do |vt,ri|
                    timeoffset = events[ri*alt_header.length]
                    vt &&= timeoffset.is_a?(Fixnum)
                  end
                  if records_valid
                    header = alt_header
                    puts "Found alternative header that matches #{event_type}: #{header.join(',')}"
                    break
                  end
                end
              end
            end
          end
        else
          puts "No header found for event type: #{event_type}"
        end
        # Now process the single long data array into a list of events with timestamps
        if header
          events_data[event_type] = (0...event_count).inject([]) do |a,block|
            index = header.length * block
            record = events[index...(index+header.length)]
            if record && record.length == header.length
              @count += 1
              event = Event.new(self,start,event_type,header,record,a[-1])
              combine_errors event
              puts "About to add new event #{event} to existing list of #{a.length} events (previous: #{a[-1] && a[-1].time})" if($debug)
              a << event
            else
              puts "Invalid '#{event_type}' data block #{block}: #{record.inspect}"
              incr_error "Invalid data block"
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
        end
      end
      find_first_and_last(events_data)
      events_data
    end
    def find_first_and_last(events_data)
      @first = nil
      @last = nil
      events_data.each do |event_type,data|
        if data.length > 0
          @first ||= data[0]
          @last ||= data[-1]
          @first = data[0] if(@first && @first.time > data[0].time)
          @last = data[-1] if(@last && @last.time < data[-1].time)
        end
      end
      if $debug
        puts "For data: #{self}"
        puts "\tFirst event: #{@first}"
        puts "\tLast event:  #{@last}"
      end
    end
  end

  class Dataset

    include ErrorCounter
    attr_reader :name, :options

    def initialize(name,options={})
      @name = name
      @data = []
      @options = options
      @time_range = options[:time_range] || DateRange.new(Config[:min_datetime],Config[:max_datetime])
      @location_range = options[:location_range] || LocationRange.everywhere
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
      @imsis ||= make_all_from_metadata('imsi')
    end

    def imei
      imeis[0]
    end

    def imeis
      @imeis ||= make_all_from_metadata('imei')
    end

    def make_all_from_metadata(field_name)
      @data.inject({}) do |a,d|
        a[d[field_name]] ||= 0
        a[d[field_name]] += d.count.to_i
        a
      end.to_a.sort do |a,b|
        b[1]<=>a[1]
      end.map do |x|
        #puts "Have #{field_name}: #{x.join('=')}"
        x[0]
      end.compact.uniq
    end

    def recent(event,key,seconds=60)
      unless event[key]
        if imei = event.file.imei
          puts "Searching for recent values for '#{key}' starting at event #{event}" if($debug)
          ev,prop=key.split(/\./)
          ar=sorted
          puts "\tSearching through #{ar && ar.length} events for event type #{ev} and property #{prop}" if($debug)
          if i=ar.index(event)
            afe = while(i>0)
              fe = ar[i-=1]
              puts "\t\tTesting event[#{i}]: #{fe}" if($debug)
              break(fe) if(fe.nil? || (event.time - fe.time) * SPERDAY > seconds || (fe.name == ev && fe.file.imei == imei))
            end
            if afe && afe.name == ev
              puts "\t\tFound event[#{i}] with #{prop} => #{afe[prop]} and time gap of #{(event.time - fe.time) * SPERDAY} seconds" if($debug)
              event[key] = afe[prop]
            end
          else
            puts "Event not found in search for recent '#{key}': #{event}"
          end
        else
          puts "Not searching for correlated data without imei: #{event}"
        end
      end
#      @recent[key] ||= ''
      event[key]
    end

    def [](key)
      @fields[key.downcase] ||= @data.map{|d| d[key]}.compact.uniq
    end

    def platforms
      self['Platform']
    end

    def models
      self['Model']
    end

    def oses
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
      (names || events_names).map do |event_type|
        [(s=sorted(event_type)[0]) && s.header]
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
        puts "Creating sorted maps for #{self}" if($debug)
        events_names.each do |name|
          is_gps = name == 'gps'
          puts "Preparing maps for #{name}" if($debug)
          @data.each do |data|
            puts "Processing #{(e=data.events[name]) && e.length} events for #{name}" if($debug)
            (events = data.events[name]) && events.each do |event|
              puts "\t\tTesting #{event.time} inside #{@time_range}" if($debug)
              if @time_range.include?(event.time)
                puts "\t\t\tEvent at #{event.time} is inside #{@time_range}" if($debug)
                if !is_gps || @location_range.nil? || @location_range.include?(event.location)
                  key = "#{event.time_key} #{name}"
                  event_hash[key] = event
                end
              end
            end
            combine_errors data
          end
          puts "After adding #{name} events, maps are #{event_hash.length} long" if($debug)
        end
        puts "Merging and sorting #{event_hash.keys.length} maps" if($debug)
        @sorted[nil] = event_hash.keys.sort.map{|k| event_hash[k]}
        puts "Sorted #{@sorted[nil].length} events" if($debug)
        locate_events if(options[:locate])
      end
      @sorted
    end

    def each_trace
      puts "Exporting GPX traces"
      trace = nil
      sorted('gps').each do |gps|
        trace ||= Trace.new(self)
        if trace.too_far(gps)
          yield trace
          trace = Trace.new(self)
        end
        trace << gps
      end
      yield trace if(trace)
    end

    def locate_events
      prev_gps = nil
      count = 0
      puts "Locating #{sorted.length} events" if($debug)
      sorted.each do |event|
        if event.name === 'gps'
          event.locate(event)
          prev_gps = event
        elsif prev_gps
          count += 1 if(event.locate_if_closer_than(prev_gps,60))
        end
      end
      puts "Located #{count} / #{sorted.length} events" if($debug)
    end

    def to_s
      (imei.to_s.length < 1 || name == imei) ? name : imeis.join(',')
    end

    def description
      "Dataset:#{name}, IMEI:#{imeis.join(',')}, IMSI:#{imsis.join(',')}, Platform:#{platforms.join(',')}, Model:#{models.join(',')}, OS:#{oses.join(',')}, Files:#{file_count}, Events:#{sorted && sorted.length}"
    end

    def self.add_file_to_datasets(datasets,file,options={})
      if File.directory?(file)
        add_directory_to_datasets(datasets,file,options)
      else
        geoptima=Geoptima::Data.new(file)
        unless geoptima.valid?
          puts "INVALID: #{geoptima.start}\t#{file}\n\n"
        else
          key = options[:combine_all] ? 'all' : geoptima.id
          datasets[key] ||= Geoptima::Dataset.new(key, options)
          datasets[key] << geoptima
        end
      end
    end

    def self.add_directory_to_datasets(datasets,directory,options={})
      Dir.open(directory).each do |file|
        next if(file =~ /^\./)
        path = "#{directory}/#{file}"
        if File.directory? path
          add_directory_to_datasets(datasets,path,options)
        elsif file =~ /\.json/i
          add_file_to_datasets(datasets,path,options)
        else
          puts "Ignoring files without JSON extension: #{path}"
        end
      end
    end

    def self.make_datasets(files, options={})
      datasets = {}
      files.each do |file|
        add_file_to_datasets(datasets,file,options)
      end
      datasets
    end

  end

end

