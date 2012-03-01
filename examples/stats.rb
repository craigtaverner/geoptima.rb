#!/usr/bin/env ruby

$debug = false
$lines = 0

ARGF.each do |line|
  $lines += 1
  fields=line.chomp.split(/\t/)
  if $headers
    puts "Processing line: #{line}" if($debug)
    fields.each_with_index do |field,index|
      puts "\tField[#{index}]: #{field}" if($debug)
      stats = $stats[index]
      stats[field] ||= 0
      stats[field] += 1
      puts "\tField[#{index}]: #{field} => #{stats[field]}" if($debug)
    end
  else
    $headers = fields
    $stats = fields.map{|h| {}}
  end
end

$headers.each_with_index do |header,index|
  stats = $stats[index]
  values = stats.keys
  perc = 100.0 * values.length.to_f / $lines.to_f
  puts "\nFound #{values.length} unique values for field '#{header}'"
  if values.length > 500
    puts "\tNot printing more values more diverse than 500"
  elsif (perc > 75)
    puts "\tNot printing more values more diverse than #{perc}%"
  else
    puts header
    values.sort.each do |value|
      value_text = (value.to_s.length < 1) ? '<empty>' : value
      puts "\t#{value_text}\t#{stats[value]}"
    end
  end
end

