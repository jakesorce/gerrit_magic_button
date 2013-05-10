class MagicData < ActiveRecord::Base
  attr_accessible :patchset, :project, :instance_id, :user, :state, :time_started, :time_up, :duration
end
