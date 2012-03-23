stats('Signal Strength', 'signal.strength', :div => 10) {|v| v}
histogram_chart 'Signal Strength'
stats('Signal Strength x5', 'signal.strength', :div => 5) {|v| v}
histogram_chart 'Signal Strength x5'
