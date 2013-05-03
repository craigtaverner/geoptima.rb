require File.join(File.dirname(__FILE__), 'spec_helper')

describe Geoptima::Locator do

  describe "#new" do
    it "locator should work on empty collections" do
      locator = Geoptima::Locator.new []
      locator.sorted.should_not == nil
      locator.located.should == nil
      
      locator.locate

      locator.sorted.length.should == 0
      locator.located.length.should == 0
    end

    it 'locator should work on one location' do
      locator = Geoptima::Locator.new [
        Geoptima::LocatableImpl.new(latitude: 56.0, longitude: 13.0, name:'gps')
      ]
      locator.sorted.length.should == 1
      locator.located.should == nil
      
      locator.locate

      locator.sorted.length.should == 1
      locator.located.length.should == 0
      locator.failed.length.should == 0
    end

    it 'locator should work on one event' do
      locator = Geoptima::Locator.new [
        Geoptima::LocatableImpl.new(name: 'unknown')
      ]
      locator.sorted.length.should == 1
      locator.located.should == nil
      
      locator.locate

      locator.sorted.length.should == 1
      locator.located.length.should == 0
      locator.failed.length.should == 1
    end

    it 'locator should work on one event and one location' do
      locator = Geoptima::Locator.new [
        Geoptima::LocatableImpl.new(timestamp: 1000, latitude: 56.0, longitude: 13.0, name: 'gps'),
        Geoptima::LocatableImpl.new(timestamp: 2000, name: 'one before')
      ]
      locator.sorted.length.should == 2
      locator.located.should == nil
      
      locator.locate

      locator.sorted.length.should == 2
      locator.located.length.should == 1
      locator.located[0].location.latitude.should == 56.0
    end

    it 'locator should work on one event and two locations' do
      locator = Geoptima::Locator.new [
        Geoptima::LocatableImpl.new(timestamp: 1000, latitude: 56.0, longitude: 13.0, name: 'gps'),
        Geoptima::LocatableImpl.new(timestamp: 2000, name: 'before and after'),
        Geoptima::LocatableImpl.new(timestamp: 3000, latitude: 56.1, longitude: 13.1, name: 'gps')
      ]
      locator.sorted.length.should == 3
      locator.located.should == nil
      
      locator.locate

      locator.sorted.length.should == 3
      locator.located.length.should == 1
      locator.located[0].location.latitude.should > 56.0
      locator.located[0].location.longitude.should > 13.0
    end

    it 'locator should work with many events and locations' do
      location_sample = create_location_sample
      locator = Geoptima::Locator.new location_sample, :window => 2

      locator.sorted.length.should == location_sample.length
      locator.located.should == nil
      
      locator.locate

      locator.sorted.length.should == location_sample.length
      locator.located.length.should == 3
      locator.failed.length.should == 1
      locator.failed[0].name.should == 'sms'
    end

  end

  describe "#locate" do

    it 'should work on a real sample file in examples/gps_dropped.json' do
      geoptima = Geoptima::Data.new('examples/gps_dropped.json')
      dataset = Geoptima::Dataset.new('gps_dropped', {})
      dataset << geoptima

      # The use of the 20s window will cause half the events to fail location
      locator = Geoptima::Locator.new dataset.sorted, :window => 20, :algorithm => 'closest'
      locator.sorted.length.should == 22
      locator.located.should == nil
      
      locator.locate

      locator.located.length.should == 3
      locator.located[0].name.should == 'call'
      locator.located[0]['status'].should == 'MT call dropped'
      locator.located[0].location.latitude.should == 34.227936
      locator.located[0].location.longitude.should == 108.869674

      locator.failed.length.should == 3
      locator.failed[0].name.should == 'call'
      locator.failed[0]['number'].should == '13709281928'

    end

    it 'should work on a real sample file in examples/sample_geoptima.json' do
      geoptima = Geoptima::Data.new('examples/sample_geoptima.json')
      dataset = Geoptima::Dataset.new('sample', {})
      dataset << geoptima

      locator = Geoptima::Locator.new dataset.sorted, :window => 20
      locator.locate
      locator.located.length.should == 384
      locator.failed.length.should == 114

      locator = Geoptima::Locator.new dataset.sorted, :window => 200
      locator.locate
      locator.located.length.should == 451
      locator.failed.length.should == 47

    end

  end

end
                                                  
