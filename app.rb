require "innate"
require_relative "lib/tiny_call_center"
require_relative "options"

require File.expand_path("model/init", TinyCallCenter::ROOT)

require "tiny_call_center/utils/fsr"
TCC::Log.level = Log4r.const_get(TCC.options.log_level)

require_relative 'node/main'
require_relative 'node/queues'
require_relative 'node/agents'
require_relative 'node/tiers'
require_relative 'node/managers'
require_relative 'node/accounts'
require_relative 'node/ribbon'
require_relative 'node/live'
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

Innate.middleware! do |mw|
  mw.use Rack::CommonLogger
  mw.use Rack::ShowExceptions
  mw.use Rack::ETag
  mw.use Rack::ConditionalGet
  mw.use Rack::ContentLength
  mw.use Rack::Static, urls: %w[/css /stylesheets /js /images], root: "public"
  mw.use Rack::Reloader
  mw.innate
end

Rack::Mime::MIME_TYPES['.coffee'] = 'text/coffeescript'

if $0 == __FILE__
  Innate.start :file => __FILE__
end
