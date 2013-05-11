require 'rubygems'
require 'sinatra'
require 'sinatra/minify'
require 'sinatra/activerecord'
require 'rack/contrib'
require 'haml'

set :database, 'sqlite:///magic.db'
set :root, File.expand_path('app', File.dirname(__FILE__))
set :pub, 'public', File.dirname(__FILE__)
set :main, File.dirname(__FILE__)
set :ami_id, 'ami-c14e21a8'

class Magic < Sinatra::Application
  @@durations = {'10' => 10, '30' => 30, '1' => '60', '2' => 120, '4' => 240, '8' => 480}  

  register Sinatra::Minify

  set :public_folder, settings.pub, File.dirname(__FILE__)
  set :js_path, "#{settings.pub}/javascripts"
  set :js_url, '/javascipts'
  set :environment, :production  

  require_relative "#{settings.root}/routes/init"
  require_relative "lib/init"

  before do
    expires 5001, :public_folder, :must_revalidate
  end
end
