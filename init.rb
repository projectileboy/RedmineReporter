require 'redmine'

Redmine::Plugin.register :redmine_reporter do
  name 'Redmine Reporter plugin'
  author 'Kurt Christensen'
  description 'Burnup chart generator for Redmine'
  version '0.0.1'
  url 'http://bitbakery.com/redmine_reporter'
  author_url 'http://bitbakery.com'

  project_module :reporter do
    permission :burnup_reporter, :reporter => :burnup
  end
  menu :project_menu, :reporter, { :controller => 'reporter', :action => 'burnup' }, :caption => 'Reporting'
end
