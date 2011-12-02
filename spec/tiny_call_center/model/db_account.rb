require_relative '../../helper'

describe 'TinyCallCenter Account' do
  behaves_like :make_account

  it 'creates accounts' do
    user = make_account('1234', 'bar', 'Foo', 'Hoge')
    user.username.should == 'FooHoge'
  end

  it 'removes accounts between specs' do
    TCC::Account[username: 'foo'].should == nil
  end

  it 'authenticates a user with the correct password' do
    make_account('1234', 'bar', 'Foo', 'Hoge')
    user = TCC::Account.authenticate('name' => 'FooHoge', 'pass' => 'bar')
    user.username.should == 'FooHoge'
  end

  describe 'utility functions' do
    behaves_like :make_account

    it 'Gets the username from an agent name' do
      TCC::Account.username('1234-MaxMustermann').should == 'MaxMustermann'
    end

    it 'gets the full name from an agent name' do
      TCC::Account.full_name('1234-MaxMustermann').should == 'MaxMustermann'
    end

    it 'gets the extension from an agent name' do
      TCC::Account.extension('1234-MaxMustermann').should == '1234'
    end

    it 'gets the agent from an agent name' do
      user = make_account('1234', 'bar', 'Max', 'Mustermann')
      TCC::Account.from_call_center_name('1234-MaxMustermann').should == user
    end

    it 'gets the agent from a full name' do
      user = make_account('1234', 'bar', 'Max', 'Mustermann')
      TCC::Account.from_full_name('1234-Max_Mustermann').should == user
    end

    it 'gets the agent from an extension' do
      TCC::Account.from_extension('1234').should == nil
      user = make_account('1234', 'bar', 'Max', 'Mustermann')
      TCC::Account.from_extension('1234').should == user
    end

    it 'lists all user names' do
      TCC::Account.all_usernames.should == ['MrAdmin']
      user = make_account('1234', 'bar', 'Max', 'Mustermann')
      TCC::Account.all_usernames.sort.should == ['MaxMustermann', 'MrAdmin']
    end
  end
end
