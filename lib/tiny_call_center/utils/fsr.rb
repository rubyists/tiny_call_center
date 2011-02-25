require "fsr/command_socket"
FSR.load_all_commands
module TinyCallCenter
  module Utils
    module FSR
      def fsr_socket(server)
        ::FSR::CommandSocket.new(:server => server, :auth => TCC.options.fs_auth)
      end

      def proxy_uri(destination)
        TCC.options.proxy_server_fmt % destination
      end

      def originate(from, to)
        account = if from.respond_to?(:registration_server)
                    from
                  else
                    Account.from_call_center_name(from)
                  end
        endpoint = "#{account.extension} XML default"
        sock = fsr_socket(account.registration_server)
        orig = if to.size < 10
          to_server = Account.registration_server(dest)
          if to_server == account.registration_server
             sock.originate(target: "user/#{to}", endpoint: endpoint)
          else
            sock.originate(target: "sofia/internal/#{to}@#{to_server}", endpoint: endpoint)
          end
        else
          sock.originate(target: proxy_uri(to), endpoint: endpoint)
        end
        res = [orig.raw, orig.run]
        sock.socket.close
        res
      end
    end
  end
end
