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

  def generate_redirect_url(user, project, patchset)
    "/magic?patchsetinfo=git fetch ssh://#{user}@gerrit.instructure.com:29418/#{project} refs/changes/#{patchset} && git cherry-pick FETCH_HEAD"
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
      md = MagicData.create!(:project => @project, :patchset => @patchset, :instance_id => @instance_id, :user => @user, :state => instance_info[2], :time_started => Time.zone.now, :duration => @converted_duration)
      Validator::EC2.store_instance_info(@instance_id, md)
      puts `ec2addtag #{@instance_id} --tag Name=magic-#{md.id}-#{@user}-#{@patchset}`
      haml :confirmation
    else
      error = 'ERROR: This would exceed the magic instance cap, please try again later.'
      redirect "#{generate_redirect_url(@user, @project, @patchset)}&error=#{error}"
    end
  end

  def portal_response(route, action, params = {}) 
    uri = URI.parse("http://#{@instance_ip}:4567")
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = nil
    request = Net::HTTP::Post.new(route) if action == 'post'
    request = Net::HTTP::Get.new(route) if action == 'get'
    request.set_form_data(params)
    http.request(request)
  end

  post '/generate' do
    instance_id = params[:instance_id]
    patchset = params[:patchset]
    project = params[:project]
    redirect_url = generate_redirect_url(params[:user], project, patchset)
    @instance_ip = `ec2-describe-instances #{instance_id}`.split('INSTANCE').last.split(' ')[2]
    if Validator::PortalHealth.sinatra_ready?(@instance_ip)
      if project == 'canvas-lms'
        response = portal_response('/checkout', 'post', {"portal_form_patchset" => "#{patchset}", :domain => "#{@instance_ip}"})
      else
       response = portal_response('/plugin_magic', 'post', {"plugin_patchset" => "#{redirect_url.split('=').last}", :domain => "#{@instance_ip}"})
      end
      if response.code == '200'
        MagicData.find_by_instance_id(instance_id).update_attributes!(:time_up => Time.zone.now)
        redirect "http://#{@instance_ip}"
      else
        error = "An Error Occurred While Spinning Up Canvas: #{response.body}"
        redirect "#{redirect_url}&spinerror=#{error}&instance_ip=#{@instance_ip}"
      end
    else
      puts `ec2stop #{instance_id}`
      MagicData.find_instance_by_id(instance_id).update_attributes!(:state => 'stopped')
      redirect "#{redirect_url}&error=Sinatra Server Never Came Up, Try Again..."
    end
  end

  get '/error_log' do
    @instance_ip = params[:instance_ip]
    portal_response('/error_log', 'get').body
  end

  post '/cancel_instance' do
    instance_id = params[:instance_id]
    puts `ec2stop #{instance_id}`
    MagicData.find_by_instance_id(instance_id).update_attributes!(:state => 'stopped')
  end
end
