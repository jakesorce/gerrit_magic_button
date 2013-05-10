module UrlHelpers
  def build_gerrit_url(patchset)
    "https://gerrit.instructure.com/#/c/#{patchset.split('/')[1]}"
  end
  module_function :build_gerrit_url
end
