require File.expand_path(File.dirname(__FILE__) + '/magic')

use Rack::StaticCache, :urls => ['/images'], :root => Dir.pwd + '/public'
use ActiveRecord::ConnectionAdapters::ConnectionManagement
run Magic.new
