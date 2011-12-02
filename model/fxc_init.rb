require_relative "../options"

if root = TinyCallCenter.options.fxc.root
  require File.join(root, 'model/init')
  p FXC::Action.all
end

