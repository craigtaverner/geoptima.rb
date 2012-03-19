#!/usr/bin/env ruby

# useful if being run inside a source code checkout
$: << 'lib'
$: << '../lib'

require 'geoptima/options'

$show_all = false

$files = Geoptima::Options.process_args do |option|
  option.a {$show_all = true}
  option.o {$output_files = true}
  option.u {$exclude_stats = true}
  option.I {$include_props = ARGV.shift.split(/[\,\;]+/)}
  option.O {$output_prefix = ARGV.shift}
end

$help = true if($files.length<0)
if $help
  puts <<EOHELP
Usage: ./stats.rb <-dha> <-I include_props> files
 -d  debug mode #{cw $debug}
 -h  print this help #{cw $help}
 -a  show all values, not just discrete ones #{cw $show_all}
 -o  output the stats to files instead of the console #{cw $output_files}
 -u  exclude stats, showing only unique lists of values #{cw $exclude_stats}
 -I  only calculate statistics for named properties #{aw $include_props}
 -O  prefix output files with specific prefix #{aw $output_prefix}
EOHELP
  exit 0
end

$files.each do |file|
  lines = 0
  headers = nil
  file_stats = nil
  File.open(file).each do |line|
    lines += 1
    fields=line.chomp.split(/[\t\,]/)
    if headers
      puts "Processing line: #{line}" if($debug)
      lac,ci=nil
      fields.each_with_index do |field,index|
        if $include_props.to_s=='' || $include_props.index(headers[index])
          puts "\tField[#{index}]: #{field}" if($debug)
          stats = file_stats[index]
          stats[field] ||= 0
          stats[field] += 1
          puts "\tField[#{index}]: #{field} => #{stats[field]}" if($debug)
          lac=field if(headers[index]=='LAC' || headers[index]=='service.lac')
          ci=field if(headers[index]=='CI' || headers[index]=='service.cell_id')
          #puts "\tSet LAC=#{lac}, CI=#{ci} based on header #{headers[index]}" if($debug)
        end
      end
      puts "\tSet LAC=#{lac}, CI=#{ci}" if($debug)
      if lac && ci
        index = headers.length - 1
        puts "\tAdding statistics for LAC=#{lac}, CI=#{ci} using additional header '#{headers[index]}'" if($debug)
        stats = file_stats[index]
        field="#{lac}-#{ci}"
        stats[field] ||= 0
        stats[field] += 1
        puts "\tField[#{index}]: #{field} => #{stats[field]}" if($debug)
      end
      if $debug
        headers.each_with_index do |header,index|
          stats = file_stats[index]
          values = stats.keys
          puts "\nFound #{values.length} unique values for field[#{index}] '#{header}'"
        end
      end
    else
      headers = fields
      headers << 'lac-ci'
      file_stats = fields.map{|h| {}}
      file_stats << {}
    end
  end

  if headers
    found=[]
    empty=[]
    headers.each_with_index do |header,index|
      stats=file_stats[index]
      found << [header,stats] if(stats.keys.length>0)
    end
    found.each do |ff|
      header,stats=*ff
      output = STDOUT
      filename = ([$output_prefix,header,$exclude_stats ? "Values" : "Stats"]).compact.join('_')+".txt"
      if $output_files
        output = File.open(filename,'w')
      end
      values = stats.keys
      perc = 100.0 * values.length.to_f / lines.to_f
      puts "Found #{values.length} unique values for field '#{header}'"
      if !$show_all && (values.length > 500)
        puts "\tNot printing more values more diverse than 500"
      elsif (!$show_all && (perc > 75))
        puts "\tNot printing more values more diverse than #{perc}%"
      else
        output.puts header
        values.sort.each do |value|
          value_text = (value.to_s.length < 1) ? '<empty>' : value
          if $exclude_stats
            output.puts "\t#{value_text}"
          else
            output.puts "\t#{value_text}\t#{stats[value]}"
          end
        end
      end
      if $output_files
        puts "\tSaved to #{filename}"
        output.close
      else
        puts
      end
    end
  else
    puts "No headers found in file #{file}"
  end

end


