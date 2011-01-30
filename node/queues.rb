# Copyright (c) 2008-2009 The Rubyists, LLC (effortless systems) <rubyists@rubyists.com>
# Distributed under the terms of the MIT license.
# The full text can be found in the LICENSE file included with this software
#
module TinyCallCenter
  class Queues
    Innate.node "/queues", self
    helper :fsr

    def index(queue_name = nil)
      @queues ||= fsr.call_center(:queue).list(queue_name).run
    end
  end
end
