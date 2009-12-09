require 'rubygems'
require 'sinatra'
require 'haml'
require 'compass'
require 'bluecloth'

Dir.glob('lib/*.rb') do |lib|
  require lib
end

configure do
  enable :sessions
  APP_CONFIG = YAML.load_file("#{Dir.pwd}/config/jrom.yml")
  DataMapper.setup(:default, APP_CONFIG['database'])

  Compass.configuration do |config|
    config.project_path = File.dirname(__FILE__)
    config.sass_dir = 'views/style'
  end

  set :sass, Compass.sass_engine_options
end

helpers do
  def require_user
    raise not_found unless logged_in?
  end

  def logged_in?
    session[:login] == true
  end

  def protected!
    response['WWW-Authenticate'] = %(Basic realm="Testing HTTP Auth") and \
      throw(:halt, [401, "Not authorized\n"]) and \
      return unless authorized?
    session[:login] = true
    redirect '/'
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials[0] == APP_CONFIG['user']  && OpenSSL::Digest::SHA1.new(@auth.credentials[1]).hexdigest == APP_CONFIG['password']
  end
end

not_found do
  haml :not_found
end

get '/' do
  @articles = Article.all(:published_at.not => nil, :order => [:published_at.desc])
  haml :index
end

get '/articles/new/?' do
  require_user

  @article = Article.new(params)
  haml :'articles/new'
end

post '/articles/new/?' do
  require_user

  @article = Article.new(params)
  if @article.save
    redirect "/articles/#{@article.url}"
  else
    haml :'articles/new'
  end
end

get '/articles/:url/edit/?' do |url|
  require_user

  @article = Article.first(:url => url)
  if @article
    haml :'articles/edit'
  else
    raise not_found
  end
end

post '/articles/:url/edit/?' do |url|
  require_user

  @article = Article.first(:url => url)
  if @article
    if @article.update(params)
      redirect "/articles/#{@article.url}"
    else
      haml :'articles/edit'
    end
  else
    raise not_found
  end
end

get '/articles/drafts/?' do
  require_user
  @articles = Article.all(:published_at => nil, :order => [:updated_at.desc])
  haml :index
end

get '/login/?' do
  protected!
end

get '/logout/?' do
  session[:login] = nil
  redirect '/'
end

get '/articles/:url/?' do |url|
  @article = Article.first(:url => url)
  if @article
    haml :'articles/show'
  else
    raise not_found
  end
end

get '/stylesheets/admin.css' do
  headers 'Content-Type' => 'text/css; charset=utf-8'
  sass :'style/admin'
end

get '/stylesheets/base.css' do
  headers 'Content-Type' => 'text/css; charset=utf-8'
  sass :'style/base'
end

get '/stylesheets/code.css' do
  headers 'Content-Type' => 'text/css; charset=utf-8'
  sass :'style/zenburn'
end
