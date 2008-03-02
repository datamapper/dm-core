require File.dirname(__FILE__) + "/spec_helper"

describe DataObject do
  
  # These specs only fail in MySQL because:
  # 1) An insert happened in the previous connection
  # 2) We are searching for NULL
  # 
  # It turns out that this is actually by design o.O:
  #   http://dev.mysql.com/doc/refman/5.0/en/myodbc-usagenotes-functionality.html
  #
  #   Certain ODBC applications (including Delphi and Access) may have trouble 
  #   obtaining the auto-increment value using the previous examples. In this case, 
  #   try the following statement as an alternative:
  #     SELECT * FROM tbl WHERE auto IS NULL;
  it "should return an empty reader" do
    repository.adapter.connection do |connection|
      sql = 'SELECT `id`, `name` FROM `zoos` WHERE (`id` IS NULL)'.gsub(/\`/, repository.adapter.class::COLUMN_QUOTING_CHARACTER)
      command = connection.create_command(sql)

      command.execute_reader do |reader|
        reader.has_rows?.should eql(ENV['ADAPTER'] == 'mysql')
      end
    end
  end
  
end
