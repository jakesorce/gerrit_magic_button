require './magic'
require 'sinatra/activerecord/rake'

task :environment do
  require './magic'
end

desc "Builds the minified CSS and JS assets."
task :minify do
  require './magic.rb'   # <= change this
  puts "Building..."

  files = Sinatra::Minify::Package.build(Magic)  # <= change this
  files.each { |f| puts " * #{File.basename f}" }
  puts "Construction complete!"
end
