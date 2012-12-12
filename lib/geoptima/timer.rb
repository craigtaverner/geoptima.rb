module Geoptima

  class Timer
    attr_reader :name, :start_time, :end_time, :duration, :full_duration, :running
    def initialize(name)
      @name = name
      reset
    end
    def reset
      @running = false
      @duration = 0
      @full_duration = 0
      @start_time = nil
      @end_time = nil
    end
    def start
      @duration = 0
      @running = true
      @start_time = Time.new
    end
    def stop
      if running
        @running = false
        @end_time = Time.new
        @duration = @end_time - @start_time
        @full_duration += @duration
      end
      @duration
    end
    def to_s
      "#{name}(#{full_duration}s)"
    end
    def describe
      "#{name}\t#{full_duration}s"
    end
  end

end

