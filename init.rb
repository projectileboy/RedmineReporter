#
# Copyright (c) Kurt Christensen, The Bit Bakery, 2011.
#
# Licensed under the Artistic License, Version 2.0 (the "License"); you may not use this
# file except in compliance with the License. You may obtain a copy of the License at:
#
# http://www.opensource.org/licenses/artistic-license-2.0.php
#
# Unless required by applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS
# OF ANY KIND, either express or implied. See the License for the specific language
# governing permissions and limitations under the License.
#

require 'redmine'

Redmine::Plugin.register :redmine_reporter do
  name 'Redmine Reporter plugin'
  author 'Kurt Christensen'
  description 'Burnup chart generator for Redmine'
  version '0.0.1'
  url 'http://github.com/projectileboy/redmine_reporter'
  author_url 'http://bitbakery.com'

  project_module :reporter do
    # TODO - Figure out the appropriate permissions, if any
    permission :burnup_reporter, :reporter => :burnup
  end
  menu :project_menu, :reporter, { :controller => 'reporter', :action => 'burnup' }, :caption => 'Reporting'

end
