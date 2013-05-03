lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
 
require 'geoptima/version'

Gem::Specification.new do |s|
  s.name = "geoptima"
  s.version = Geoptima::VERSION
  s.authors = "Craig Taverner"
  s.email = 'craig@amanzi.com'
  s.homepage = "http://github.com/craigtaverner/geoptima.rb"
  s.rubyforge_project = 'geoptima'
  s.summary = "Ruby access to Geoptima JSON files"
  s.description = <<-EOF

Geoptima is a suite of applications for measuring and locating
mobile/cellular subscriber experience on GPS enabled smartphones.  It is
produced by AmanziTel AB in Helsingborg, Sweden, and supports many phone
manufacturers, with free downloads from the various app stores, markets or
marketplaces.  This Ruby library is capable of reading the JSON format files
produced by these phones and reformating them as CSV, GPX and PNG for
further analysis in Excel.  This is a simple and independent way of
analysing the data, when compared to the full-featured analysis applications
and servers available from AmanziTel.  If you want to analyse a limited
amount of data in excel, or with Ruby, then this GEM might be for you.  If
you want to analyse large amounts of data, from many subscribers, or over
long periods of time then rather consider the NetView and Customer IQ
applications from AmanziTel at www.amanzitel.com.

Current features available in the library and the show_geoptima command:
* Import one or many JSON files
* Organize data by device id (IMEI) into datasets
* Split by event type
* Time ordering and time correlation (associate data from one event to another):
** Add GPS locations to other events (time window and interpolation algorithms)
** Add signal strenth, battery level, etc. to other events
* Export event tables to CSV format for further processing in excel
* Make and export GPS traces in GPX and PNG format for simple map reports

The amount of data possible to process is limited by memory, since all data
is imported in ruby data structures for procssing.  If you need to process
larger amounts of data, you will need a database-driven approach, like that
provided by AmanziTel's NetView and Customer IQ solutions.  This Ruby gem is
actually used by parts of the data pre-processing chain of 'Customer IQ',
but it not used by the main database and statistics engine that generates
the reports.

EOF

  s.require_path = 'lib'
  s.files        = Dir.glob("{bin,lib,rdoc}/**/*").reject{|x| x=~/(tmp|target|test-data)/ || x=~/~$/} +
                   Dir.glob("examples/*rb") + Dir.glob("examples/sample*json") + 
                   %w(README.rdoc CHANGELOG CONTRIBUTORS Gemfile geoptima.gemspec)
  s.executables  = ['show_geoptima','geoptima_file_time','geoptima_file_time_stats','csv_chart','csv_stats','csv_merge']

  s.extra_rdoc_files = %w( README.rdoc )
  s.rdoc_options = ["--quiet", "--title", "Geoptima.rb", "--line-numbers", "--main", "README.rdoc", "--inline-source"]

  s.add_dependency('multi_json',">= 1.1.0")
  s.add_dependency('json_pure',">= 1.6.5")
  s.required_ruby_version = ">= 1.8.6"
end
