require 'rubygems'
require 'dm-core'

desc "Migrate the database: ALERT THIS WILL DESTROY ALL THE DATA"
task :migrate do
  require File.dirname(__FILE__) + '/config/jrom.rb'
  Dir.glob('lib/*.rb') do |lib|
    require lib
  end

  DataMapper.auto_migrate!
end
