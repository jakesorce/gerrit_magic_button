module UrlHelpers
  def self.build_gerrit_url(patchset)
    "https://gerrit.instructure.com/#/c/#{patchset.split('/')[1]}"
  end
end
