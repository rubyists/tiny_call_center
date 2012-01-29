module Innate
  module Helper
    module Fsr
      def fsr
        @fsr_command_socket ||= FSR::CommandSocket.new(server: ::TinyCallCenter.options.command_server)
      end
    end
  end
end
