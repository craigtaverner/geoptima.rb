module Geoptima

  VERSION = "0.1.10"

  class Version
    attr_reader :comparator, :version, :major, :minor, :patch
    def initialize(text)
      @comparator,@version = clean_version(text)
      @major,@minor,@patch=@version.split(/\./)
    end
    def clean_version(version)
      comparator,cleaned = "==", version
      if version =~ /^([\>\<\=]+)(\d+\.\d+\.\d+)/
        comparator = $1[0..2]
        cleaned = $2
      end
      [comparator,cleaned]
    end
    def to_i
      unless @version_int
        base = 1
        @version_int = version.split(/\./).reverse.inject(0) do |acc,v|
          acc += base * v.to_i
          base *= 100
          acc
        end
      end
      @version_int
    end
    def to_s
      version
    end
    def as_geoptima_version
      self
    end
    def compare(other)
      ogv = other.as_geoptima_version
      self.to_i.send(ogv.comparator, ogv.to_i)
    end
    def diff(other)
      other.as_geoptima_version.to_i - self.to_i
    end
  end

  def self.version
    @@version ||= VERSION.as_geoptima_version
  end

  def self.version=(test_version)
    @@version = test_version.as_geoptima_version
  end

  def self.assert_version(expected_ver, test_mode = false)
    unless version.compare(expected_ver)
      diff = version.diff(expected_ver)
      if(!test_mode)
        puts "Geoptima library version mismatch. Expected #{expected_ver}, found #{version}."
        exit -1
      end
      return diff
    end
    true
  end

end

class String
  def as_geoptima_version
    Geoptima::Version.new(self)
  end
end

if $PROGRAM_NAME =~ /version.rb$/
  test_lib_versions = ["0.1.5","0.1.6","0.1.7"]
  test_comparators = ["","==","<","<=",">",">="]
  test_lib_versions.each do |lib_ver|
    Geoptima.version = lib_ver
    puts "Testing with library version: #{lib_ver}"
    puts (["Version"]+test_comparators.map{|v| "#{v}    "[0..3]}).join(" | ")
    test_lib_versions.map do |test_ver|
      puts "#{test_ver}   | "+(test_comparators.map do |comp|
        expected_ver = "#{comp}#{test_ver}"
        Geoptima.assert_version expected_ver, true
      end.map{|v| "    #{v}"[-4..-1]}.join(" | "))
    end
  end
end

