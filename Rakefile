require 'rubygems'

desc "Migrate the database: ALERT THIS WILL DESTROY ALL THE DATA"
task :migrate do

  Dir.glob('lib/*.rb') do |lib|
    require lib
  end
  APP_CONFIG = YAML.load_file("#{Dir.pwd}/config/jrom.yml")
  DataMapper.setup(:default, APP_CONFIG['database'])
  DataMapper.auto_migrate!

end
