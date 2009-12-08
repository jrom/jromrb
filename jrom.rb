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
  @posts = Post.all(:published_at.not => nil, :order => [:published_at.desc])
  haml :index
end

get '/posts/new/?' do
  require_user

  @post = Post.new(params)
  haml :'posts/new'
end

post '/posts/new/?' do
  require_user

  @post = Post.new(params)
  if @post.save
    redirect "/#{@post.url}"
  else
    haml :'posts/new'
  end
end

get '/posts/:url/edit/?' do |url|
  require_user

  @post = Post.first(:url => url)
  if @post
    haml :'posts/edit'
  else
    raise not_found
  end
end

post '/posts/:url/edit/?' do |url|
  require_user

  @post = Post.first(:url => url)
  if @post
    if @post.update(params)
      redirect "/#{@post.url}"
    else
      haml :'posts/edit'
    end
  else
    raise not_found
  end
end

get '/posts/drafts/?' do
  require_user
  @posts = Post.all(:published_at => nil, :order => [:updated_at.desc])
  haml :index
end

get '/login/?' do
  protected!
end

get '/logout/?' do
  session[:login] = nil
  redirect '/'
end

get '/:url/?' do |url|
  @post = Post.first(:url => url)
  if @post
    haml :'posts/show'
  else
    raise not_found
  end
end
