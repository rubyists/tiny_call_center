require "innate"
require_relative "lib/tiny_call_center"
require_relative "options"

require File.expand_path("model/init", TinyCallCenter::ROOT)

require_relative "lib/tiny_call_center/utils/fsr"
TCC::Log.level = Log4r.const_get(TCC.options.log_level)

require_relative 'node/main'
require_relative 'node/queues'
require_relative 'node/agents'
require_relative 'node/tiers'
require_relative 'node/managers'
require_relative 'node/accounts'
require_relative 'node/ribbon'
require_relative 'node/ribbon2'
require_relative 'node/live'
require_relative 'node/live2'
require_relative 'node/live_log'

require_relative 'node/fxc/user'
require_relative "localization"

module Innate
  class Request
    def accept_language(string = env['HTTP_ACCEPT_LANGUAGE'])
      return [] unless string

      accept_language_with_weight(string).map{|lang, weight| lang }
    end
    alias locales accept_language

    def accept_language_with_weight(string = env['HTTP_ACCEPT_LANGUAGE'])
      string.to_s.gsub(/\s+/, '').split(',').
        map{|chunk|        chunk.split(';q=', 2) }.
        map{|lang, weight| [lang, weight ? weight.to_f : 1.0] }.
        sort_by{|lang, weight| -weight }
    end
  end
end

class WorkAroundRackStatic
  def initialize(app)
    @app = app
    @static = Rack::Static.new(
      @app,
      urls: %w[/bootstrap /css /stylesheets /js /images],
      root: "public",
      cache_control: 'public'
    )
  end

  def call(env)
    warn "calling WorkAroundRackStatic"
    warn env['PATH_INFO']
    if env['PATH_INFO'] == '/'
      @app.call(env)
    else
      @static.call(env)
    end
  end
end

Innate.middleware :live do
  use Rack::CommonLogger
  use Rack::ShowExceptions
  use Rack::ETag
  use Rack::ConditionalGet
  use Rack::ContentLength
  use WorkAroundRackStatic
  use Rack::Reloader
  run Innate.core
end

Innate.middleware :dev do
  use Rack::CommonLogger
  use Rack::ShowExceptions
  use Rack::ETag
  use Rack::ConditionalGet
  use Rack::ContentLength
  use WorkAroundRackStatic
  use Rack::Reloader
  run Innate.core
end


Rack::Mime::MIME_TYPES['.coffee'] = 'text/coffeescript'

if $0 == __FILE__
  Innate.start :file => __FILE__
end
