module Geoptima

  VERSION = "0.1.4"

  def self.version_as_int(ver)
    base = 1
    ver.split(/\./).reverse.inject(0) do |acc,v|
      acc += base * v.to_i
      base *= 100
      acc
    end
  end

  def self.compare_version(expected_ver)
    version_as_int(expected_ver) - version_as_int(VERSION)
  end

  def self.assert_version(expected_ver)
    if expected_ver.to_s != VERSION
      diff = compare_version(expected_ver)
      if(diff != 0)
        msg = diff > 0 ? "against and older library" : "an older script"
        puts "Geoptima library version mismatch. Expected #{expected_ver}, found #{VERSION}. Are you running #{msg}?"
        exit -1
      end
    end
  end

end
