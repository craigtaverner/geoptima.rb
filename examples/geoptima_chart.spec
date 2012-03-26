# Signal strength in 10dBm category ranges bar chart
stats('Signal Strength', 'signal.strength') {|s| v=s.to_i;(v<-40 && v>-130) ? v : nil}
stats('Signal Strength Groups', 'signal.strength', :div => 10) {|s| v=s.to_i;(v<-40 && v>-130) ? v : nil}
histogram_chart 'Signal Strength Groups' # per 10dbm range
histogram_chart 'Signal Strength' # filtered
#histogram_chart 'Signal.Strength' # unfiltered

# TrafficCount
categories = [0,1000,10000,100000,1000000,10000000,100000000,1000000000]

stats 'Traffic Count TX (Mobile)', 'trafficCount.txBytes', 'trafficCount.interface',
  :categories => categories, :filter => {:interface => 'MOBILE'}

stats 'Traffic Count TX (WiFi)', 'trafficCount.txBytes', 'trafficCount.interface',
  :categories => categories, :filter => {:interface => 'WIFI'}

stats 'Traffic Count RX (Mobile)', 'trafficCount.rxBytes', 'trafficCount.interface',
  :categories => categories, :filter => {:interface => 'MOBILE'}

stats 'Traffic Count RX (WiFi)', 'trafficCount.rxBytes', 'trafficCount.interface',
  :categories => categories, :filter => {:interface => 'WIFI'}

histogram_chart 'Traffic Count TX (Mobile)'
histogram_chart 'Traffic Count TX (WiFi)'
histogram_chart 'Traffic Count RX (Mobile)'
histogram_chart 'Traffic Count RX (WiFi)'

# Traffic and FTP Speed
['Traffic','FTP'].each do |test|
  ['Upload','Download'].each do |direction|
    ['Mobile','WiFi'].each do |interface|
      event = "#{test.downcase}Speed"
      name =  "#{test} Speed #{direction} (#{interface})"
      filter = {:direction => direction.upcase, :interface => interface.upcase}
      stats(name, "#{event}.speed", "#{event}.direction", "#{event}.interface", :div => 10, :filter => filter)
      histogram_chart name
    end
  end
end

# Storage Status
stats 'Storage Size', 'storageStatus.totalSize', :group => :days
stats 'Storage Total', 'storageStatus.totalSize'
category_chart 'Storage Size'
histogram_chart 'Storage Total'

# SMS, MMS
stats 'SMS', 'sms.status', :group => :days
stats 'MMS', 'mms.status', :group => :days
histogram_chart 'sms.status'
category_chart 'SMS'
histogram_chart 'mms.status'
category_chart 'MMS'

# Browser render time
categories = [0,1000,5000,20000,50000,100000,500000,2000000,10000000]
categories = [0,1000,4000,16000,32000,64000,128000,256000,1000000,4000000,16000000]
stats 'Page Render Time', 'browserDedicatedTest.pageRendered', :categories => categories
histogram_chart 'Page Render Time'

# http request in 1/10 of a second
stats 'HTTP Request Time', 'httpRequest.speed', :div => 100
histogram_chart 'HTTP Request Time'

# Multi-column chart for different event types over days of the week
stats 'Call Status', 'call.status', :group => :days
stats 'Data Status', 'data.status', :group => :days
stats 'Events', 'Event', :group => :days
stats 'Browser Success', 'browserDedicatedTest.success', :group => :days
category_chart 'Data Status'
category_chart 'Events'
category_chart 'Call Status'
category_chart 'Browser Success'

# The same stats as before but in line charts
line_chart 'Data Status'
line_chart 'Events'
line_chart 'Call Status'
line_chart 'Browser Success'

# Access mode (SOS, etc al.)
stats "Access Mode", "mode.mode", :group => :days
stats("Access Problem", "mode.mode", :group => :days) {|m| (m=='NORMAL') ? nil : m}
histogram_chart "Access Mode"
histogram_chart "Access Problem"

# Top-10 charts for very diverse values like LAC-CI
stats('URL Path', 'browser.URL') {|v| v && v.gsub(/%(\w{2})/){|m| $1.to_i(16).chr}[0..50]}
stats('URL', 'browser.URL') {|v| v && v.gsub(/%(\w{2})/){|m| $1.to_i(16).chr}.gsub(/(\w)\/.*/,'\1')}
stats('Apps', 'runningApps.appName', 'runningApps.state') {|name,state| (state=='STARTED') ? name : nil}
stats('LAC,CI', 'service.lac', 'service.cell_id', :filter => {:lac => /\d/, :cell_id => /\d/}) {|lac,ci| "#{lac},#{ci}"}
histogram_chart 'LAC,CI', :top => 10, :side => true
histogram_chart 'Event', :top => 10, :side => true
histogram_chart 'URL', :top => 10, :side => true
histogram_chart 'Apps', :top => 10, :side => true

# Success counters for active test URLs
%w(www.baidu.com
www.bing.com
www.ebay.com
www.facebook.com
www.google.com
www.twitter.com
www.wikipedia.org
www.yahoo.com
www.youtube.com).each do |url|
  stats "Active URL #{url}", "browserDedicatedTest.success", "browserDedicatedTest.url", :filter => {:url => url}, :group => :days
  histogram_chart "Active URL #{url}"
end

#stats('Events', 'Event', :group => :days) {|v| v}
#category_chart 'Event'
#category_chart 'Events'
#histogram_chart 'LAC-CI'
#histogram_chart 'LACCI', :top => 10, :side => true
#histogram_chart 'RSSI'
#histogram_chart 'RSSI2'
#histogram_chart 'RSSI Ranges'

