# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
set :output, "/Users/jake/code/gerrit_magic_button/logs/cron_log.log"
#
every 10.minutes do
  command "ruby /Users/jake/code/gerrit_magic_button/lib/shutdown.rb"
end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever
