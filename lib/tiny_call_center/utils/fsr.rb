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
        Log.devel "<< Originate #{from} => #{to} >>"
        account = if from.respond_to?(:registration_server)
                    from
                  else
                    Account.from_call_center_name(from)
                  end
        endpoint = "#{account.extension} XML default"
        sock = fsr_socket(account.registration_server)
        Log.devel "<< Originate #{from} => #{to} @ #{account.registration_server} >>"
        opts = {
          origination_caller_id_number: account.extension,
          sip_callee_id_number: to,
          caller_id_number: to,
          tcc_action: 'originate',
          origination_caller_id_name: "'#{account.full_name}'"
        }
        orig = if to.size < 10
          to_server = Account.registration_server(to)
          if to_server == account.registration_server
             sock.originate(target: "user/#{to}", target_options: opts, endpoint: endpoint)
          else
            if to_server == '127.0.0.1'
              sock.originate(target: "loopback/#{to}/default/XML", target_options: opts, endpoint: endpoint)
            else
              sock.originate(target: "sofia/internal/#{to}@#{to_server}", target_options: opts, endpoint: endpoint)
            end
          end
        else
          sock.originate(target: proxy_uri(to), target_options: opts, endpoint: endpoint)
        end
        res = [orig.raw, orig.run]
        Log.devel "<< Origination command #{res} >>"
        sock.socket.close
        res
      end
    end
  end
end
