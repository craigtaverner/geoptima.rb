# Signal strength in 10dBm category ranges bar chart
stats 'Signal Strength', 'signal.strength', :div => 10
histogram_chart 'Signal.Strength'

# Multi-column chart for different event types over days of the week
stats 'Call Status', 'call.status', :group => :days
stats 'Data Status', 'data.status', :group => :days
stats 'Events', 'Event', :group => :days
category_chart 'Data Status'
category_chart 'Events'
category_chart 'Call Status'

# The same stats as before but in line charts
line_chart 'Data Status'
line_chart 'Events'
line_chart 'Call Status'

# Top-10 charts for very diverse values like LAC-CI
stats('URL', 'browser.URL') {|v| v && v.gsub(/%(\w{2})/){|m| $1.to_i(16).chr}[0..50]}
stats('Apps', 'runningApps.appName', 'runningApps.state') {|name,state| (state=='STARTED') ? name : nil}
histogram_chart 'LAC-CI', :top => 10, :side => true
histogram_chart 'Event', :top => 10, :side => true
histogram_chart 'URL', :top => 10, :side => true
histogram_chart 'Apps', :top => 10, :side => true


#stats('Events', 'Event', :group => :days) {|v| v}
#category_chart 'Event'
#category_chart 'Events'
#histogram_chart 'LAC-CI'
#histogram_chart 'LACCI', :top => 10, :side => true
#histogram_chart 'RSSI'
#histogram_chart 'RSSI2'
#histogram_chart 'RSSI Ranges'

