# PlantUML plugin for Redmine
# Copyright (C) 2011  Motoyuki Terajima
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require 'redmine'

Dir::foreach(File.join(File.dirname(__FILE__), 'lib')) do |file|
  next unless /\.rb$/ =~ file
  require file
end

Redmine::Plugin.register :redmine_plantuml do
  name 'Redmine PlantUML plugin'
  author 'Motoyuki Terajima'
  description 'This is a PlantUML plugin for Redmine'
  url "http://github.com/trmmy/redmine_plantuml" if respond_to?(:url)
  version '0.1'
  requires_redmine :version_or_higher => '0.9.0'

  if ENV['OS'] = 'Windows_NT' 
    settings :default => {
      'java_home'=>"C:/Program Files/Java/jdk1.7.0",
      'plantuml_jar'=>"C:/apps/plantuml/bin/plantuml.jar",
      'dot'=>"C:/Program Files/Graphviz2.28.0/bin/dot.exe",
      'font'=>"MS Gothic",
    }, :partial => 'plantuml_settings/edit'
  else
    settings :default => {
      'java_home'=>"/usr/lib/jvm/java",
      'plantuml_jar'=>"/usr/share/java/plantuml.jar",
      'dot'=>"/usr/bin/dot",
      'font'=>"MS Gothic",
    }, :partial => 'plantuml_settings/edit'
  end
end

