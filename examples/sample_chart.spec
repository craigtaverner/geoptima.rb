#stats('LACCI', 'LAC', 'CI') {|lac,ci| lac+'-'+ci}
#stats('RSSI2', 'RSSI') {|v| v}
#stats('RSSI Ranges', 'RSSI', :div => 10) {|v| v}
stats('Call Status', 'call.status', :group => :days) {|v| v}
stats('Data Status', 'data.status', :group => :days) {|v| v}
stats('Events', 'Event', :group => :days) {|v| v}
stats('Apps', 'runningApps.appName', :group => :days) {|v| v}
#stats('Events', 'Event', :group => :days) {|v| v}
#category_chart 'Event'
#category_chart 'Events'
category_chart 'Data Status'
line_chart 'Data Status'
category_chart 'Events'
line_chart 'Events'
category_chart 'Call Status'
line_chart 'Call Status'
category_chart 'Apps'
line_chart 'Apps'
#histogram_chart 'Signal.Strength'
#histogram_chart 'LAC-CI'
#histogram_chart 'LACCI', :top => 10, :side => true
#histogram_chart 'RSSI'
#histogram_chart 'RSSI2'
#histogram_chart 'RSSI Ranges'

