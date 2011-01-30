require "innate"
require_relative "lib/tiny_call_center"
require_relative "options"

require TinyCallCenter::ROOT/"model/init"

require "fsr"
require "fsr/command_socket"
FSR::Cmd.load_command('call_center')

require_relative 'node/main'
require_relative 'node/queues'
require_relative 'node/agents'
require_relative 'node/tiers'

require_relative 'node/accounts'
require_relative 'node/ws'
require_relative 'node/orderly'

Innate.middleware! do |mw|
  mw.use Rack::CommonLogger
  mw.use Rack::ShowExceptions
  mw.use Rack::ETag
  mw.use Rack::ConditionalGet
  mw.use Rack::Static, :urls => %w[/css /stylesheets /js /coffee], :root => "public"
  mw.innate
end

Rack::Mime::MIME_TYPES['.coffee'] = 'text/coffeescript'

if $0 == __FILE__
  Innate.start :file => __FILE__
end
