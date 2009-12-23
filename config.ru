# Rack config file
# Jordi Romero (jrom)

require File.join(File.dirname(__FILE__), 'jrom.rb')

log = File.new("log/#{Sinatra::Application.environment}.log", "a+")
STDOUT.reopen(log)
STDERR.reopen(log)

run JROMRB::Application
