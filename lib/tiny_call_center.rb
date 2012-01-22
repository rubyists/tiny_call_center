require "pathname"
require 'log4r'
require 'log4r/configurator'

Log4r::Configurator.custom_levels(:DEBUG, :DEVEL, :INFO, :NOTICE, :WARN,
                                  :ERROR, :CRIT)

require 'fsr'

class Pathname
  def /(other)
    join(other.to_s)
  end
end

module TinyCallCenter
  Log = FSR::Log
  ROOT = (Pathname(__FILE__)/'../..').expand_path
  LIBROOT = ROOT/:lib
  MIGRATION_ROOT = ROOT/:migrations
  MODEL_ROOT = ROOT/:model
  SPEC_HELPER_PATH = ROOT/:spec
end

TCC = TinyCallCenter
