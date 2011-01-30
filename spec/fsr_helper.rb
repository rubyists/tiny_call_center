begin
  require "fsr"
rescue LoadError
  require "rubygems"
  require "fsr"
end
require FSR::ROOT/"../spec/fsr_listener_helper"
require FSR::ROOT/"fsr/listener/outbound"
require FSR::ROOT/"fsr/listener/mock"
require "em-spec/bacon"
