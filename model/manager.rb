module TinyCallCenter
  class Manager < Sequel::Model
    set_dataset TinyCallCenter.db[:managers]

    # Check the includes and excludes to make sure the caller (cid_to)
    # or the callee (cid) are included in what the user is allowed to listen to
    # Then make sure the callee and caller arent in the users' excluded extensions
    # both self.include and self.exclude are regular expression in string format
    # as created by /^(1234)$/.to_s type notation, cid and cid_to are expected to
    # be strings
    def authorized_to_listen?(cid, cid_to)
      includes = Regexp.new(include)
      excludes = Regexp.new(exclude) if exclude

      if excludes
        (cid =~ includes || cid_to =~ includes) &&
       !(cid =~ excludes || cid_to =~ excludes)
      else
        cid =~ includes || cid_to =~ includes
      end
    end
  end
end
