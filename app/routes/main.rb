require "#{settings.root}/models/magic_data"
require "#{settings.main}/lib/validator"
require 'net/http'
require 'uri'

class Magic < Sinatra::Application
  include Validator

  def parse_patchset_info(info)
    parts = []
    parts << info.split('changes/').last.split(' ').first #patchset
    parts << info.split('ssh://').last.split('@').first #username
    parts << info.split('29418/').last.split(' ').first #project
    parts
  end

  get '/' do
    haml :index
  end

  get '/magic' do
    patchset_info = params[:patchsetinfo]
    puts patchset_info
    if !patchset_info || patchset_info !~ /^git\s(fetch|pull)\sssh:\/\/[a-zA-Z]*@gerrit.instructure.com:29418\/\S*\srefs\/changes\/\d+\/\d+\/\d+/
      haml :index
    else
      info = parse_patchset_info(patchset_info)
      @patchset = info.first
      @user = info[1]
      @project = info.last
      @error = params[:error]
      @spin_error = params[:spinerror]
      @instance_ip = params[:instance_ip]
      haml :magic
    end
  end

  post '/request_instance' do
    @patchset = params[:patchset]
    @user = params[:user]
    @project = params[:project]
    @duration = params[:duration]
    @converted_duration = @@durations[@duration.split(' ').first] 
    if Validator::EC2.check_instance_cap
      instance_info = `ec2-run-instances #{settings.ami_id} --instance-type m2.xlarge -g canvasportal`.split('INSTANCE').last.split(' ')
      @instance_id = instance_info[0]
      md = MagicData.create!(:project => @project, :patchset => @patchset, :instance_id => @instance_id, :user => @user, :state => instance_info[2], :time_started => Time.now, :duration => @converted_duration)
      Validator::EC2.store_instance_info(@instance_id, md)
      puts `ec2addtag #{@instance_id} --tag Name=magic-#{md.id}-#{@user}-#{@patchset}`
      haml :confirmation
    else
      error = 'ERROR: This would exceed the magic instance cap, please try again later.'
      redirect "/magic?patchsetinfo=git fetch ssh://#{@user}@gerrit.instructure.com:29418/#{@project} refs/changes/#{@patchset} && git cherry-pick FETCH_HEAD&error=#{error}"
    end
  end

  post '/generate' do
    instance_id = params[:instance_id]
    patchset = params[:patchset]
    project = params[:project]
    redirect_url = "/magic?patchsetinfo=git fetch ssh://#{params[:user]}@gerrit.instructure.com:29418/#{project} refs/changes/#{patchset} && git cherry-pick FETCH_HEAD"
    instance_ip = `ec2-describe-instances #{instance_id}`.split('INSTANCE').last.split(' ')[2]
    if Validator::PortalHealth.sinatra_ready?(instance_ip)
      puts 'make post to sinatra and handle'
      uri = URI.parse("http://#{instance_ip}:4567")
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = nil
      if project == 'canvas-lms'
        request = Net::HTTP::Post.new('/checkout')
        request.set_form_data({"portal_form_patchset" => "#{patchset}"})
      else
        request = Net::HTTP::Post.new('/plugin_patchset')
        request.set_form_data({"plugin_patchset" => "#{redirect_url}"})
      end
      response = http.request(request)
      if response.code == '200'
        MagicData.find_by_instance_id(instance_id).update_attributes!(:time_up => Time.now)
        redirect "http://#{instance_ip}"
      else
        error = "An Error Occurred While Spinning Up Canvas: #{response.body}"
        redirect "#{redirect_url}&spinerror=#{error}&instance_ip=#{instance_ip}"
      end
    else
      puts 'never came up'
      puts `ec2stop #{instance_id}`
      MagicData.find_instance_by_id(instance_id).update_attributes!(:state => 'stopped')
    end
  end

  get '/error_log' do
    uri = URI.parse("http://#{params[:instance_ip]}:4567")
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = nil
    request = Net::HTTP::Get.new('/error_log')
    response = http.request(request)
    response.body
  end

  post '/cancel_instance' do
    instance_id = params[:instance_id]
    puts `ec2stop #{instance_id}`
    MagicData.find_by_instance_id(instance_id).update_attributes!(:state => 'stopped')
  end
end
