require 'rubygems'
require 'sinatra'
require 'haml'

Dir.glob('lib/*.rb') do |lib|
  require lib
end

configure do
  require File.dirname(__FILE__) + '/config/jrom.rb'
  enable :sessions
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
    @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == ['admin', 'password']
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
