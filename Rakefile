$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)

require 'rake'
require 'rspec/core/rake_task'
require 'rdoc/task'

require "geoptima/version"

desc "Run all specs"
RSpec::Core::RakeTask.new("spec") do |t|
  t.rspec_opts = ["-c"]
end

task :check_commited do
  status = %x{git status}
  fail("Can't release gem unless everything is committed") unless status =~ /nothing to commit \(working directory clean\)|nothing added to commit but untracked files present/
end

desc "clean all, delete all files that are not in git"
task :clean_all do
  system "git clean -df"
end

desc "create the executables in bin"
task :make_bin do
  Dir.glob('examples/*.rb').each do |file|
    bin = file.gsub(/\.rb/,'').gsub(/examples/,'bin')
    system "cp #{file} #{bin}"
  end
end

desc "create the gemspec"
task :build => [:make_bin] do
  system "gem build geoptima.gemspec"
end

desc "release gem to gemcutter"
task :release => [:check_commited, :build] do
  system "gem push geoptima-#{Geoptima::VERSION}.gem"
end

desc "Generate documentation for Geoptima.rb"
RDoc::Task.new do |rdoc|
  rdoc.rdoc_dir = 'doc/rdoc'
  rdoc.title    = "Geoptima.rb #{Geoptima::VERSION}"
  rdoc.options << '--webcvs=http://github.com/craigtaverner/geoptima.rb/tree/master/'
  rdoc.options << '-f' << 'horo'
  rdoc.options << '-c' << 'utf-8'
  rdoc.options << '-m' << 'README.rdoc'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

require 'rake/testtask'
Rake::TestTask.new(:test_generators) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

desc 'Upload documentation to RubyForge.'
task 'upload-docs' do
  sh "scp -r doc/rdoc/* " +
    "craig@amanzi.com:/var/www/gforge-projects/geoptima/"
end

task :default => 'spec'
