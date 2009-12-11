# Jordi Romero

require 'dm-core'
require 'dm-validations'
require 'dm-timestamps'

class Article
  include DataMapper::Resource

  property :id, Serial
  property :url, String, :key => true
  property :title, String
  property :introduction, String, :length => 200
  property :body, Text
  property :published_at, DateTime

  timestamps :at

  validates_is_unique :url
  validates_present :title

  def published=(value)
    puts "Doing publication"
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
