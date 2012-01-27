require 'fsr/listener/inbound'
FSR.load_all_commands

module TCC
  class FSListener < FSR::Listener::Inbound
    LISTENERS = {}

    def self.log(msg, level = :devel)
      Log4r::NDC.push("FSR")
      Log.__send__(level, msg)
      Log4r::NDC.pop
    end

    def log(msg, level = :devel)
      self.class.log(msg, level)
    end

    def self.execute(reg_server, &block)
      log execute: reg_server

      if listener = LISTENERS[reg_server]
        listener.execute(&block)
      else
        create(reg_server){|l| l.execute(&block) }
      end
    end

    def self.create(server, &block)
      log create: server

      EventMachine.connect(server, 8021, self, host: server, port: 8021, auth: 'ClueCon', &block)
    end

    def receive_data(data)
      
    end

    def initialize(*args)
      super
      @cc_cmd = FSR::Cmd::CallCenter.new(nil, :agent)
      @cc_queue = EM::Queue.new
      @execute_queue = EM::Queue.new
      LISTENERS[@host] = self
    end

    def before_session
      EM.defer{ execution }
    end

    def callcenter!(&given_block)
      @cc_queue.push given_block

      @cc_queue.pop do |block|
        block.call(@cc_cmd)
        log @cc_cmd.raw, :info
        api(@cc_cmd.raw)
      end
    end

    def execute(&block)
      @execute_queue.push(block)
    end

    private

    def execution
      @execute_queue.pop do |block|
        block.call(self)
        EM.defer{ execution }
      end
    end
  end
end
