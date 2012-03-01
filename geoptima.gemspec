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
Geoptima is a suite of applications for measuring and locating mobile/cellular subscriber experience on GPS enabled smartphones.
It is produced by AmanziTel AB in Helsingborg, Sweden, and supports many phone manufacturers, with free downloads from the
various app stores, markets or marketplaces. This Ruby library is only capable of reading the JSON format files priduced by these phones
and reformating them as CSV for further analysis in Excel. This is a simple and independent way of analysing the data, when
compared to the full-featured analysis applications and servers available from AmanziTel. If you want to analyse a limited amount
of data in excel, or with Ruby, then this GEM might be for you. If you want to analyse large amounts of data, from many subscribers, or over long periods of time
then rather consider the NetView and Customer IQ applications from AmanziTel at www.amanzitel.com.
EOF

  s.require_path = 'lib'
  s.files        = Dir.glob("{bin,lib,examples}/**/*").reject{|x| x=~/(tmp|target|test-data)/} + %w(README.rdoc CHANGELOG CONTRIBUTORS Gemfile geoptima.gemspec)
  s.executables  = ['show_geoptima']
  s.has_rdoc = true
  s.extra_rdoc_files = %w( README.rdoc )
  s.rdoc_options = ["--quiet", "--title", "geoptima.rb", "--opname", "index.html", "--line-numbers", "--main", "README.rdoc", "--inline-source"]
  s.required_ruby_version = ">= 1.8.7"
end
