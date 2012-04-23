#!/usr/bin/ruby

def cw(val)
  val.nil? ? '' : "(#{val})"
end

def aw(val)
  val.nil? ? '' : "#{val.inspect}"
end

module Geoptima

  class Options

    attr_reader :args, :options, :debug

    def initialize(debug=nil)
      @debug = debug
      @args = []
      @options = {}
    end
    def add(*args,&block)
      puts "Adding option processing for: #{args[0]}" if(debug)
      @options[args[0].to_s] = block
    end
    def method_missing(symbol,*args,&block)
      puts "Adding option processing for: #{symbol}" if(debug)
      @options[symbol.to_s] = block
    end
    def process(a)
      puts "Looking for match to option #{a}" if(debug)
      @options.each do |opt,block|
        puts "Comparing option #{a} to known option #{opt}" if(debug)
        if opt === a
          puts "Calling block for option #{a}: #{block.inspect}" if(debug)
          block.call
          return
        end
      end
      puts "Unknown option: -#{a}"
    end
    def to_s
      "Options[#{@options.keys.sort.join(', ')}]: #{args.join(', ')}"
    end

    def self.process_args(debug=nil)
      options = Options.new(debug)
      options.add('f') {$flush_stdout = true}
      options.add('v') {$print_version = true}
      options.add('d') {$debug = true}
      options.add('h') {$help = true}
      puts "Processing options: #{options}" if(debug)
      yield options if(block_given?)
      while arg = ARGV.shift do
        if arg =~ /^\-(\w+)/
          $1.split(//).each do |a|
            options.process a
          end
        else
          options.args << arg
        end
      end
      puts "Geoptima Gem Version: #{Geoptima::VERSION}" if($print_version)
      STDOUT.sync if($flush_stdout)
      options.args
    end

  end

end

