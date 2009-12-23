require 'rubygems'
require 'sinatra'
require 'haml'
require 'compass'
require 'bluecloth'
require 'xmlrpc/server'
require 'xmlrpc/marshal'
require 'digest/md5'

module JROMRB
  class Application < Sinatra::Base


    Dir.glob('lib/*.rb') do |lib|
      require lib
    end

    configure do
      set :root, File.dirname(__FILE__)
      set :static, true
      enable :sessions
      JROMRB::APP_CONFIG = YAML.load_file("#{Dir.pwd}/config/jrom.yml")
      DataMapper.setup(:default, APP_CONFIG['database'])

      Compass.configuration do |config|
        config.project_path = File.dirname(__FILE__)
        config.sass_dir = 'views/style'
      end

      set :sass, Compass.sass_engine_options
    end

    helpers do
      include Helpers
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
      @tag = Rack::Utils.unescape(tag)
      @articles = Article.tagged_with(@tag)
      @title = "Articles about '#{@tag}' by Jordi Romero"
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
      comment.save
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
  end # class Application
end # module
