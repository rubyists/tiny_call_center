require "innate"
require_relative "lib/tiny_call_center"
require_relative "options"

require TinyCallCenter::ROOT/"model/init"

require "tiny_call_center/utils/fsr"
TCC::Log.level = Log4r.const_get(TCC.options.log_level)
require_relative 'node/main'
require_relative 'node/queues'
require_relative 'node/agents'
require_relative 'node/tiers'

require_relative 'node/accounts'
require_relative 'node/ribbon'
require_relative 'node/live'
require_relative 'node/live_log'

Innate.middleware! do |mw|
  mw.use Rack::CommonLogger
  mw.use Rack::ShowExceptions
  mw.use Rack::ETag
  mw.use Rack::ConditionalGet
  mw.use Rack::Static, :urls => %w[/css /stylesheets /js /coffee /images], :root => "public"
  mw.innate
end

Rack::Mime::MIME_TYPES['.coffee'] = 'text/coffeescript'

if $0 == __FILE__
  Innate.start :file => __FILE__
end
