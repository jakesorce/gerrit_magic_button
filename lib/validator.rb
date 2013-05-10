module Validator
  module EC2
    @instance_cap = 10
    
    def self.check_instance_cap
      MagicData.where("state == 'running' or state == 'pending'").count > @instance_cap ? false : true
    end

    def self.store_instance_info(instance_id, magic_data)
      while instance_status(instance_id) != 'running'
        next
      end
      state = instance_status(instance_id)
      magic_data.update_attributes!(:state => state)
    end

    def self.determine_instance_shutdown
      Dir.chdir(File.expand_path(File.dirname(__FILE__) + '/../')) do |dir|
        require 'sinatra/activerecord'
        require "#{dir}/app/models/magic_data"
        Time.zone = 'America/Denver'
        ActiveRecord::Base.establish_connection(
          "adapter" => "sqlite3",
          "database"  => "magic.db"
        )
        MagicData.all.each do |md|
          if md.state == 'running' && md.time_up
            if Time.now > md.time_up + md.duration.minutes
              puts `ec2stop #{md.instance_id}`
              md.update_attributes!('state' => 'stopped')
            end
          elsif (md.state == 'running' || md.state == 'pending') && !md.time_up && Time.zone.now > md.time_started + 1.hour
            puts `ec2stop #{md.instance_id}`
            md.update_attributes!('state' => 'stopped')
          end
        end
      end
    end

    def self.instance_status(instance_id)
      `ec2-describe-instances #{instance_id}`.split('INSTANCE').last.split(' ')[4]
    end
  end 

  module PortalHealth
    def self.sinatra_ready?(ip, port = '4567')
      Timeout::timeout(500) do
        begin 
          while true do
            begin
              Timeout::timeout(1) do
                begin
                  s = TCPSocket.new(ip, port)
                  s.close
                  return true
                rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
                  #try again
                  retry
                end 
              end
            rescue Timeout::Error
              #try again
              retry
            end
          end
        rescue Timeout::Error
          return false
        end
      end
    end
  end 
end
