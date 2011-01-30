module TinyCallCenter
  class Manager < Sequel::Model
    set_dataset :managers

    # Check the includes and excludes to make sure the caller (cid_to)
    # or the callee (cid) are included in what the user is allowed to listen to
    # Then make sure the callee and caller arent in the users' excluded extensions
    # both self.include and self.exclude are regular expression in string format
    # as created by /^(1234)$/.to_s type notation, cid and cid_to are expected to 
    # be strings
    def authorized_to_listen?(cid, cid_to)
      ins = Regexp.new self.include
      exs = self.exclude ? Regexp.new(self.exclude) : nil
      if exs                             
        ((cid =~ ins) || (cid_to =~ ins)) && !((cid_to =~ exs) or (cid =~ exs))
      else
        (cid =~ ins) or (cid_to =~ ins)
      end
    end
  end
end
