require 'optparse'
require 'yaml'

module Validator
  module EC2
    DB = YAML::load_file(File.expand_path(File.dirname(__FILE__) + '/../config/database.yml'))
    @instance_cap = 10
    
    def self.options
      options = {}
      optparse = OptionParser.new do |opts|
        options[:shutdown] = false
        opts.on('-s', '--shutdown', 'shutdown') do
          options[:shutdown] = true
        end
      end
      optparse.parse!

      if options[:shutdown]
        puts determine_instance_shutdown
      end
    end  

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
    
    def self.stop_instance(magic_data)
      puts `ec2-terminate-instances #{magic_data.instance_id}`
      magic_data.update_attributes!('state' => 'stopped')
    end

    def self.determine_instance_shutdown
      Dir.chdir(File.expand_path(File.dirname(__FILE__) + '/../')) do |dir|
        require 'sinatra/activerecord'
        require "#{dir}/app/models/magic_data"
        Time.zone = 'America/Denver'
        ActiveRecord::Base.establish_connection(adapter: DB['adapter'], database: DB['database'])
        MagicData.all.each do |md|
          if md.state == 'running' && md.time_up
            if Time.zone.now > md.time_up + md.duration.minutes
              stop_instance(md)
            end
          elsif (md.state == 'running' || md.state == 'pending') && !md.time_up && Time.zone.now > md.time_started + 1.hour
            stop_instance(md)
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
                  retry
                end 
              end
            rescue Timeout::Error
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

Validator::EC2.options
