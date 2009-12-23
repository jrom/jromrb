# Jordi Romero

require 'dm-core'
require 'dm-validations'
require 'dm-timestamps'
require 'dm-tags'

class Article
  include DataMapper::Resource

  property :id, Serial
  property :url, String, :required => true
  property :title, String, :required => true
  property :introduction, String, :length => 200
  property :body, Text, :required => true
  property :published_at, DateTime

  has_tags_on :tags
  has n, :comments

  timestamps :at

  validates_is_unique :url

  before :save do
    self.url.downcase!
  end

  def published=(value)
    if value == "1"
      attribute_set(:published_at, Time.now) if published_at.nil?
    else
      attribute_set(:published_at, nil)
    end
  end

  def to_metaweblog
   {
    :postid => id,
    :dateCreated => created_at,
    :description => body,
    :title => title,
    :wp_slug => "#{url}",
    :link => "/#{url}",
    :permaLink => "/#{url}",
    :mt_tags => (introduction || "..."),
    :post_status => (published_at.nil? ? "0" : "1"),
    }
  end

end

class Tag
  def url
    Rack::Utils.escape(self.name)
  end
end

class Comment
  include DataMapper::Resource

  property :id, Serial
  property :name, String, :length => (1..50)
  property :email, String, :required => true, :format => :email_address
  property :url, String
  property :body, Text, :required => true
  property :published_at, DateTime, :required => true
  belongs_to :article, :required => true

end
