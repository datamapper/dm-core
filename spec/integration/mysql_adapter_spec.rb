require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

begin
  gem 'do_mysql', '=0.9.0'
  require 'do_mysql'

  DataMapper.setup(:mysql, "mysql://localhost/dm_integration_test")

rescue LoadError => e
  describe 'do_mysql' do
    it 'should be required' do
      fail "MySQL integration specs not run! Could not load do_mysql: #{e}"
    end
  end
end
