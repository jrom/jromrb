
module JROMRB
  module Helpers

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

    def markdown(input)
      BlueCloth.new(input).to_html
    end

    def secure_markdown(input)
      markdown(Rack::Utils.escape_html(input))
    end

  end # module Helpers
end # module JROMRB
