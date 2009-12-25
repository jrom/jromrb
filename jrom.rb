require 'rubygems'
require 'sinatra'
require 'haml'
require 'compass'
require 'bluecloth'
require 'xmlrpc/server'
require 'xmlrpc/marshal'
require 'digest/md5'
require 'logger'

module JROMRB
  class Application < Sinatra::Base


    Dir.glob('lib/*.rb') do |lib|
      require lib
    end

    configure do
      Log = Logger.new("log/#{Sinatra::Application.environment}.log")
      Log.level = Logger::INFO
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
      haml :'misc/not_found'
    end

    before do
      headers "Content-Type" => "text/html; charset=utf-8"
    end


    # Articles

    # Main page: Articles index
    get '/' do
      @articles = Article.all(:published_at.not => nil, :order => [:published_at.desc])
      haml :index
    end

    # Drafts
    get '/articles/drafts/?' do
      require_user
      @articles = Article.all(:published_at => nil, :order => [:updated_at.desc])
      haml :index
    end

    # Article page
    get '/articles/:url/?' do |url|
      @article = Article.first(:url => url)
      @comment = Comment.new
      if @article
        require_user unless @article.published_at
        @title = "'#{@article.title}' by Jordi Romero"
        haml :'articles/show'
      else
        raise not_found
      end
    end

    # New article form
    get '/articles/new/?' do
      require_user

      @article = Article.new(params)
      haml :'articles/new'
    end

    # Save new article
    post '/articles/new/?' do
      require_user

      @article = Article.new(params)
      if @article.save
        redirect "/articles/#{@article.url}"
      else
        haml :'articles/new'
      end
    end

    # Edit article form
    get '/articles/:url/edit/?' do |url|
      require_user

      @article = Article.first(:url => url)
      if @article
        haml :'articles/edit'
      else
        raise not_found
      end
    end

    # Save edited article
    post '/articles/:articleurl/edit/?' do |articleurl|
      require_user
      params.delete('articleurl') # Because Sinatra sets params[:articleurl] and the model hates it
      @article = Article.first(:url => articleurl)
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

    # Articles with a tag
    get '/tags/:tag/?' do |tag|
      @tag = Rack::Utils.unescape(tag)
      @articles = Article.tagged_with(@tag)
      @title = "Articles about '#{@tag}' by Jordi Romero"
      haml :index
    end


    # Comments

    # New comment
    post '/comments/new' do
      @article = Article.first(:id => params[:article_id])
      unless @article
        redirect '/'
      end
      @comment = Comment.new(params)

      if logged_in?
        @comment.name = "Jordi Romero"
        @comment.email = @comment.antispam = "jordi@jrom.net"
        @comment.url = "http://jrom.net/"
        Log.info "And now the comment looks like: #{@comment.inspect}"
      elsif @comment.role == "author"
        Log.info "Somebody is trying to fake!"
        @comment.name = "Anonymous"
        @comment.email = @comment.antispam = "anonymous@anonymous.com"
        @comment.url = ""
      end

      if @comment.save
        redirect "/articles/#{@article.url}\#comment-#{@comment.id}"
      else
        require_user unless @article.published_at
        @title = "'#{@article.title}' by Jordi Romero"
        haml :'articles/show'
      end
    end

    # Content pages

    # About & Jordi Romero pages
    get '/about/?' do
      @title = "About Jordi Romero"
      haml :'misc/about'
    end

    get '/jordi-romero/?' do
      redirect '/about', 301
    end

    # Contact page
    get '/contact/?' do
      @title = "Contact with Jordi Romero"
      haml :'misc/contact'
    end


    # Feeds

    # Articles feed
    get '/feed/?' do
      content_type 'application/atom+xml', :charset => 'utf-8'
      @articles = Article.all(:published_at.not => nil, :order => [:published_at.desc])
      haml :'articles/feed', { :format => :xhtml, :layout => false }
    end

    # Comments feed
    get '/comments/feed/?' do
      content_type 'application/atom+xml', :charset => 'utf-8'
      @comments = Comment.all(:order => [:published_at.desc])
      haml :'comments/feed', { :format => :xhtml, :layout => false }
    end

    # Stylesheets

    # Production stylesheet
    get '/stylesheets/production.css' do
      headers 'Content-Type' => 'text/css; charset=utf-8'
      cache_page '/stylesheets/production.css', sass(:'style/production')
    end

    # Misc

    get '/login/?' do
      protected!
    end

    get '/logout/?' do
      session[:login] = nil
      redirect '/'
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

  end # class Application
end # module
