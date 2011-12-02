require_relative '../../helper'

describe 'TinyCallCenter Manager' do
  behaves_like :make_account

  it 'creates a manager' do
    manager = TCC::Manager.create(username: 'FooHoge')
    user = make_account('1234', 'bar', 'Foo', 'Hoge')

    user.manager?.should == true
  end
end
