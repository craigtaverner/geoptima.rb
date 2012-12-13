#!/usr/bin/env ruby

# useful if being run inside a source code checkout
$: << 'lib'
$: << '../lib'

require 'geoptima/version'
require 'geoptima/file_time'

Geoptima::assert_version(">=0.1.17")

ARGV.each do |filename|
  puts "#{(filename.to_s+" "*40)[0..40]} -->   #{Geoptima::FileTime.from_file(filename).join(', ')}"
end
