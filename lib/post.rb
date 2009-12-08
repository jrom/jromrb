# Jordi Romero

require 'dm-core'
require 'dm-validations'
require 'dm-timestamps'

class Post
  include DataMapper::Resource

  property :url, String, :key => true
  property :title, String
  property :introduction, String
  property :body, Text
  property :published_at, DateTime

  timestamps :at

  validates_is_unique :url
  validates_present :title

end
