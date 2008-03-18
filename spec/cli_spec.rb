require __DIR__ + 'spec_helper'

describe DataMapper::CLI do

  describe "connection string" do
  end

  describe "CLI options" do

    describe "-m or --models" do
      it "should " do
        
      end
    end
    
    # Entire configuration structure, useful for testing scenarios.
    describe "-c or --config" do
      it "should " do
        
      end
    end
    
    # database connection configuration yaml file.
    describe "-y or --yaml" do
      it "should " do
        
      end
    end
    
    # logfile
    describe "-l or --log" do
      it "should " do
        
      end
    end
    
    # environment to use with database yaml file.
    describe "-e, --environment" do
      it "should " do
        
      end
    end
    
    # Loads Merb app settings: config/database.yml, app/models
    # Loads Rails app settings: config/database.yml, app/models
    describe "--merb, --rails" do
      it "should " do
                
      end
    end

    describe "database options" do
    
      # adapter {mysql, pgsql, etc...}
      describe "-a, --adapter" do
        it "should support mysql" do
        end
        
        it "should support pgsql" do
        end
        
        it "should support sqlite" do
        end
      end

      # database name
      describe "-d, --database" do
        it "should set options[:database]" do
          
        end
      end

      # user name
      describe "-u, --username" do
        it "should set options[:username]" do
          
        end
      end

      # password
      describe "-p, --password" do
        it "should set options[:password]" do
          
        end
      end

      # host
      describe "-h, --host" do
        it "should set options[:host]" do
          
        end
      end

      # socket
      describe "-s, --socket" do
        it "should set options[:socket]" do
          
        end
      end
      
      # port
      describe "-o, --port" do
        it "should " do
          
        end
      end
      
    end

  end

end

