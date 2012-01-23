require "em-jack"
require "json"
module TCC
  class JackTube < EMJack::Connection
    def process_job(ribbon, channel, json)
      case channel.to_s
      when /insert/
        ribbon.backbone_create(channel, json)
      when /update/
        ribbon.backbone_update(channel, json)
      when /delete/
        ribbon.backbone_delete(channel, json)
      end
    end

    def process_jobs(ribbon)
      each_job do |job|
        channel, json = job.body.split("\t",2)
        json = JSON.parse json
        delete(job).callback do
          process_job(ribbon, channel, json)
          TCC::Log.debug "deleted #{{channel => json}}"
        end
      end
    end

    def watch_socket(tube, ribbon)
      watch(tube).callback do |_tube|
        TCC::Log.info "Jack is listening on #{_tube}"
        process_jobs(ribbon)
      end
    end
  end
end


