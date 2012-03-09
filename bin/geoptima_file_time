#!/usr/bin/env ruby

require 'date'

$root=DateTime.parse("1970-01-01 00:00:00")
ARGV.each do |arg|
  base,seconds=arg.split(/_/)
  date = ($root + seconds.to_f/(60*60*24))
  puts "#{date}\t#{arg}"
end
