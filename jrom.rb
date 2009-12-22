require 'rubygems'
require 'sinatra'
require 'haml'
require 'compass'
require 'bluecloth'
require 'xmlrpc/server'
require 'xmlrpc/marshal'
require 'cgi'
require 'digest/md5'

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

  def unauthorized
    response['WWW-Authenticate'] = %(Basic realm="Testing HTTP Auth") and \
      throw(:halt, [401, "Not authorized\n"])
  end

  def protected!
    unauthorized and return unless authorized?
    session[:login] = true
    redirect '/'
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? && @auth.basic? && @auth.credentials && authenticate(@auth.credentials[0], @auth.credentials[1])
  end

  def authenticate(username, password)
    APP_CONFIG['user'] == username && APP_CONFIG['password'] == OpenSSL::Digest::SHA1.new(password).hexdigest
  end

  def gravatar_for(email, size=90)
    hash = Digest::MD5.hexdigest(email)
    "http://www.gravatar.com/avatar/#{hash}?s=#{size}"
  end

  def relative_time_ago(from_time)
    distance_in_minutes = (((Time.now - from_time.to_time).abs)/60).round
    case distance_in_minutes
      when 0..1 then 'about a minute'
      when 2..44 then "#{distance_in_minutes} minutes"
      when 45..89 then 'about 1 hour'
      when 90..1439 then "about #{(distance_in_minutes.to_f / 60.0).round} hours"
      when 1440..2879 then '1 day'
      when 2880..43199 then "#{(distance_in_minutes / 1440).round} days"
      when 43200..86399 then 'about 1 month'
      when 86400..525599 then "#{(distance_in_minutes / 43200).round} months"
      when 525600..1051199 then 'about 1 year'
      else "over #{(distance_in_minutes / 525600).round} years"
    end
  end

  def pluralize(n, singular, plural = nil)
    if n == 1
      "#{n} #{singular}"
    else
      "#{n} #{(plural ? plural : singular+"s")}"
    end
  end
end

not_found do
  haml :not_found
end

before do
  headers "Content-Type" => "text/html; charset=utf-8"
end


post '/xmlrpc' do
  xmlrpc = XMLRPC::BasicServer.new
  xmlrpc.add_handler('metaWeblog.getRecentPosts') do |blog,username,password,number|
    unauthorized unless authenticate(username, password) || authorized?
    Article.all.map{ |a| a.to_metaweblog}
  end

  xmlrpc.add_handler('metaWeblog.editPost') do |postid,username,password,struct,publish|
    unauthorized unless authenticate(username, password) || authorized?
    article = Article.first(:id => postid.to_i)
    article.title = struct["title"]
    article.body = struct["description"]
    article.save
    article.to_metaweblog
  end

  xmlrpc.add_handler('metaWeblog.getPost') do |postid,username,password|
    unauthorized unless authenticate(username, password) || authorized?
    Article.first(:id => postid.to_i).to_metaweblog
  end

  response = xmlrpc.process(@request.body.read)
  headers 'Content-Type' => 'text/xml'
  response
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

get '/tags/:tag/?' do |tag|
  @articles = Article.tagged_with(CGI.unescape(tag))
  @tag = tag
  @title = "Articles about '#{tag}' by Jordi Romero"
  haml :index
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

post '/comments/new' do
  article = Article.first(:id => params[:article_id])
  comment = Comment.new(params)
  comment.published_at = Time.now
  redirect "/articles/#{article.url}\#comment-#{comment.id}"
end

get '/articles/:url/?' do |url|
  @article = Article.first(:url => url)
  if @article
    require_user unless @article.published_at
    @title = "'#{@article.title}' by Jordi Romero"
    haml :'articles/show'
  else
    raise not_found
  end
end

get '/feed/?' do
  content_type 'application/atom+xml', :charset => 'utf-8'
  @articles = Article.all(:published_at.not => nil, :order => [:published_at.desc])
  haml :feed, {:format => :xhtml, :layout => false}
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
