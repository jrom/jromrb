require 'rubygems'

task :db do

  Dir.glob('lib/*.rb') do |lib|
    require lib
  end
  APP_CONFIG = YAML.load_file("#{Dir.pwd}/config/jrom.yml")
  DataMapper.setup(:default, APP_CONFIG['database'])

end

desc "Migrate the database: ALERT THIS WILL DESTROY ALL THE DATA"
task :migrate => :db do

  DataMapper.auto_migrate!

end

desc "Upgrade the DB without destroying it"
task :upgrade => :db do

  DataMapper.auto_upgrade!

end
