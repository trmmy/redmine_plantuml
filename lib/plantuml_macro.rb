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

# original doc => 
# dot file => erase
# image file => move
# File
#  Image
#  Dot
#  Work
# Uml
# Config

require 'redmine'
require 'fileutils'
require 'nkf'

module Redmine
  module WikiFormatting
    class << self

      MACROS_RE = /
                    (!)?                        # escaping
                    (
                    \{\{                        # opening tag
                    ([\w]+)                     # macro name
                    (\((((?!\}\}).)*)\))?       # optional arguments
                    \}\}                        # closing tag
                    )
                  /xm
    end
  end
end

# plantuml(title, simple_description)
# plantuml_include([[project]/wikipage]/attached_filename)
# plantuml_ref([[project]/wikipage]/uml_title)

module PlantumlMacro
  Redmine::WikiFormatting::Macros.register do

    # =======================================================
    macro :plantuml do |obj, args|

      title = args.shift.sub(/"(.*)"/, "\\1")
      concat_title = title.clone
      if concat_title =~ /^[0-9a-zA-Z_\-]+$/
        concat_title.gsub!(/[\s]+/,'_')
      else
        concat_title = concat_title.hash
      end
      pageid = obj.page.title.hash if obj
      pageid = pageid || "issue"
      if args[0]=="nosvek"
        use_svek = false
        args.shift
      else
        use_svek = true
      end
      filename = "#{obj.page.project.name.hash}_#{pageid}_#{concat_title}"
      dotfilename = "#{filename}.dot"
      pngfilename = "#{filename}.png"
      desc = args.join(',') # ',' in plant uml description

      dotdir = "#{::RAILS_ROOT}/dotfiles"
      FileUtils.mkdir_p(dotdir)

      uml = File.open("#{dotdir}/work_#{dotfilename}",'w')

      uml.puts "@startuml #{pngfilename}"
      uml.puts "title #{title}" unless title.empty?
      uml.puts "skinparam classAttributeIconSize 0"

      font_name=Setting.plugin_redmine_plantuml['font']
      uml.puts "skinparam defaultFontName #{font_name}" if font_name
      uml.puts "skinparam svek true" if use_svek

      annotated_relation = desc.clone
      klass = ""
      last_type = ""
      annotated_relation.gsub!("<br />", "\n")
      annotated_relation.gsub!(/^((.*)\/\/\s+(aggregate|composite|associate))|((class|interface)\s+(\w+))/) do |m|
        st, type, base = $2, $3, $6
        if base.nil?
          st.gsub!(";", "")
          sts = st.split(/\s+/)
          role = sts.pop
          as = sts.pop
          case type
          when "associate"
            uml.puts "#{as} \"#{role}\" <-- #{klass}"
          when "aggregate"
            uml.puts "#{as} \"#{role}\" <--o #{klass}" # klass‚É’l‚ª‚È‚¢‚Æ<-- o ‚É‚È‚é
          when "composite"
            uml.puts "#{as} \"#{role}\" <--* #{klass}"
          end
        else
          klass = base
        end
      end

      class_relation = desc.clone
      klass = ""
      last_type = ""
      class_relation.gsub!("<br />", " ")
      class_relation.gsub!(/((class|interface)\s+(\w+))|([\s]extends\s(\w+(\s*,\s*\w+)*))|([\s]implements\s+(\w+(\s*,\s*\w+)*))/) do |m|
        type, base, cls, inf = $2, $3, $5, $8
        if ! base.nil?
          last_type = type
          klass = base
        elsif ! cls.nil?
          cls.split(",").each do |i|
            uml.puts "#{last_type} #{i}"
            uml.puts "#{i} <|-- #{klass}"
          end
        elsif ! inf.nil?
          inf.split(",").each do |i|
            uml.puts "interface #{i}"
            uml.puts "#{i} <|.. #{klass}"
          end
        end
      end

      desc.clone.each do |lines|
        lines.split("<br />").each do |line|
          line.gsub!(/[\s]((extends|implements)\s([\w,\s]+))/, "")
          line.gsub!(/^[\s]*private[\s]/,"-")
          line.gsub!(/^[\s]*protected[\s]/,"#")
          line.gsub!(/^[\s]*public[\s]/,"+")
          line.gsub!(/&lt;/,"<")
          line.gsub!(/&gt;/,">")
          line.gsub!("<del>", "-")
          line.gsub!("</del>", "-")
          line.gsub!("<p>", "")
          line.gsub!("</p>", "")
          line.gsub!(/\t/, "")
          line.gsub!("<strong>", "*")
          line.gsub!(";", "")
          line.gsub!(/^(.*)\/\/\s+(aggregate|composite|associate).*$/, "")
          line.gsub!(/\/\/.*/, "")

          uml.puts line
        end
      end

      uml.puts "@enduml"
      uml.close

      if !File.exists?("#{::RAILS_ROOT}/public/images/plantuml/#{pngfilename}") ||
          !File.exists?("#{dotdir}/#{dotfilename}") ||
          !FileUtils.identical?("#{dotdir}/#{dotfilename}", "#{dotdir}/work_#{dotfilename}")
        FileUtils.copy("#{dotdir}/work_#{dotfilename}", "#{dotdir}/#{dotfilename}")

        java_home=Setting.plugin_redmine_plantuml['java_home'] 
        plantuml_jar=Setting.plugin_redmine_plantuml['plantuml_jar']
        graphviz_dot=Setting.plugin_redmine_plantuml['dot']

        IO.popen("#{java_home}/bin/java -jar #{plantuml_jar} -charset UTF-8 -graphvizdot \"#{graphviz_dot}\" #{dotdir}/#{dotfilename}", 'r') { |pipe|
          pipe.each { |line|
            puts line
          }
        }
        FileUtils.move("#{dotdir}/#{pngfilename}", "#{::RAILS_ROOT}/public/images/plantuml/#{pngfilename}")
      end
      FileUtils.remove("#{dotdir}/work_#{dotfilename}")
      return "<img \"plantuml diagram - #{title}\" src=\"#{Redmine::Utils::relative_url_root}/images/plantuml/#{pngfilename}?#{Time.now.to_i}\" />"
    end

    # =======================================================
    desc " references description !{{plantuml_ref([[project:]wikipage/]title)}}"
    macro :plantuml_ref do |obj, args|

      return nil unless args.size == 1

      args[0] =~ /^\s*(([^\/:]+):)?(([^\/:]+)\/)?([^\/:]+)/
      pj, wikipage, title = $2, $4, $5
      
      if wikipage.nil?
        pj, wikipage = obj.page.project, pj
      else
        pj = Project.find_by_name(pj)
      end
      
      if wikipage.nil?
        wikipage = obj.page
      else
        wikipage = pj.wiki.find_page(wikipage)
      end

      uml_title_hash = title.clone
      if uml_title_hash =~ /^[0-9a-zA-Z_\-]+$/
        uml_title_hash.gsub!(/[\s]+/,'_')
      else
        uml_title_hash = uml_title_hash.hash
      end

      return nil unless File.exists?("#{::RAILS_ROOT}/public/images/plantuml/#{pj.name.hash}_#{wikipage.title.hash}_#{uml_title_hash}.png")

    o = ""
    o << "<img \"plantuml diagram - #{title}\" "
    o << "src=\"#{Redmine::Utils::relative_url_root}/images/plantuml/"
    o << "#{pj.name.hash}_#{wikipage.title.hash}_#{uml_title_hash}.png?"
    o << "#{Time.now.to_i}\" />"
    return o
  end

  # =======================================================
  desc " interpret attached file !{{plantuml_include([[project:]wikipage/]filename)}}"
  macro :plantuml_attached do |obj, args|

    return nil unless args.size == 1 

    args[0] =~ /^\s*(([^\/:]+):)?(([^\/:]+)\/)?([^\/:]+)/
    pj, wikipage, filename = $2, $4, $5
    
    if wikipage.nil?
      pj, wikipage = obj.page.project, pj
    else
      pj = Project.find_by_name(pj)
    end
    
    if wikipage.nil?
      wikipage = obj.page
    else
      wikipage = pj.wiki.find_page(wikipage)
    end
    
    at = wikipage.attachments.reverse.find do |attachment|
      attachment.filename == filename
    end

    dotfilename = at.disk_filename
    pngfilename = "#{dotfilename}.png"
    
    f = File::open("#{::RAILS_ROOT}/files/#{dotfilename}", 'r')
    l = f.find do |line|
      line.include? "@startuml"
    end
    f.close
    ls = l.strip.split(/\s+/)
    if ls.size==2
      pngfilepath = ls[1]
    else
      pngfilepath = dotfilename.sub(/\.[^.]+$/, ".png")
    end

    dotdir = "#{::RAILS_ROOT}/dotfiles"
    FileUtils.mkdir_p(dotdir)

    if !File.exists?("#{::RAILS_ROOT}/public/images/plantuml/#{pngfilename}") ||
        !File.exists?("#{dotdir}/#{dotfilename}") ||
        !FileUtils.identical?("#{::RAILS_ROOT}/files/#{dotfilename}", "#{dotdir}/#{dotfilename}")
      FileUtils.copy("#{::RAILS_ROOT}/files/#{dotfilename}", "#{dotdir}/#{dotfilename}")

      java_home=Setting.plugin_redmine_plantuml['java_home'] 
      plantuml_jar=Setting.plugin_redmine_plantuml['plantuml_jar']
      graphviz_dot=Setting.plugin_redmine_plantuml['dot']

      IO.popen("#{java_home}/bin/java -jar #{plantuml_jar} -charset UTF-8 -graphvizdot \"#{graphviz_dot}\" #{dotdir}/#{dotfilename}", 'r') { |pipe|
        pipe.each { |line|
          puts line
        }
      }
      FileUtils.move("#{dotdir}/#{pngfilepath}", "#{::RAILS_ROOT}/public/images/plantuml/#{pngfilename}")
    end
    return "<img \"plantuml diagram - #{pj.name}:#{wikipage.title}/#{filename}\" src=\"#{Redmine::Utils::relative_url_root}/images/plantuml/#{pngfilename}?#{Time.now.to_i}\" />"
  end

  # =======================================================
  desc " using repository  !{{plantuml_repos([[project:][repository|]path/to/file[@rev])}}"
  macro :plantuml_source do |obj, args|
    return nil unless args.size == 1 

    # plantuml_source(project:path/to/file@rev)
    # plantuml_source(project:repository|path/to/file@rev)
    args[0] =~ /^\s*(([^\/:]+):)?(([^\/\|@:]+)\|)?([^\|@:]+)(@(.*))?/
    project, scm, path, rev = $2, $4, $5, $7

    return nil unless path

    if project
      project = Project.find_by_name(project)
    else
      project = obj.page.project
    end
    
    repository = project.repository
    #    repository = project.repositories.detect{ |repo| repo.identifirer == scm }
    repo_id = scm || "main"

    return nil unless repository

    rev = repository.latest_changeset.revision unless rev

    content = repository.cat(path, rev)
    return nil unless content
    

    path =~ /(.+\/)?([^\/]+)/
    filename = $2
    
    concat_title = "#{path}@#{rev}".hash

    filename = "#{project.name.hash}_#{repo_id}_#{concat_title}"
    dotfilename = "#{filename}.dot"
    pngfilename = "#{filename}.png"


    dotdir = "#{::RAILS_ROOT}/dotfiles"
    FileUtils.mkdir_p(dotdir)
    File.open("#{dotdir}/work_#{dotfilename}",'wb:UTF-8'){ |f| 
      f.write(NKF.nkf('-wxm0', content))
    }

    f = File::open("#{dotdir}/work_#{dotfilename}", 'r')
    l = f.find do |line|
      line.include? "@startuml"
    end
    ls = l.strip.split(/\s+/)
    f.close

    #    File::open("#{dotdir}/work_#{dotfilename}", 'r'){ |f|
    #      ls = f.find { |l| l.include? "@startuml"}.strip.split(/\s+/)
    #    }

    if ls.size==2
      pngfilepath = ls[1]
    else
      pngfilepath = dotfilename.sub(/\.[^.]+$/, ".png")
    end

    if !File.exists?("#{::RAILS_ROOT}/public/images/plantuml/#{pngfilename}") ||
        !File.exists?("#{dotdir}/#{dotfilename}") ||
        !FileUtils.identical?("#{dotdir}/#{dotfilename}", "#{dotdir}/work_#{dotfilename}")
      FileUtils.copy("#{dotdir}/work_#{dotfilename}", "#{dotdir}/#{dotfilename}")

      java_home=Setting.plugin_redmine_plantuml['java_home'] 
      plantuml_jar=Setting.plugin_redmine_plantuml['plantuml_jar']
      graphviz_dot=Setting.plugin_redmine_plantuml['dot']

      # file read @plantuml...
      IO.popen("#{java_home}/bin/java -jar #{plantuml_jar} -charset UTF-8 -graphvizdot \"#{graphviz_dot}\" #{dotdir}/#{dotfilename}", 'r') { |pipe|
        pipe.each { |line|
          puts line
        }
      }
      FileUtils.move("#{dotdir}/#{pngfilepath}", "#{::RAILS_ROOT}/public/images/plantuml/#{pngfilename}")
    end
    FileUtils.remove("#{dotdir}/work_#{dotfilename}")
    return "<img \"plantuml diagram - #{project.name}:#{repo_id}|#{path}@#{rev}\" src=\"#{Redmine::Utils::relative_url_root}/images/plantuml/#{pngfilename}?#{Time.now.to_i}\" />"
  end

  # =======================================================
  macro :plantuml_head do |obj, args|

    title = args.shift.sub(/"(.*)"/, "\\1")
    concat_title = title.clone
    if concat_title =~ /^[0-9a-zA-Z_\-]+$/
      concat_title.gsub!(/[\s]+/,'_')
    else
      concat_title = concat_title.hash
    end
    pageid = obj.page.title.hash if obj
    pageid = pageid || "issue"
    if args[0]=="nosvek"
      use_svek = false
      args.shift
    else
      use_svek = true
    end
    filename = "#{obj.page.project.name.hash}_#{pageid}_#{concat_title}"
    dotfilename = "#{filename}.dot"
    pngfilename = "#{filename}.png"

    dotdir = "#{::RAILS_ROOT}/dotfiles"
    FileUtils.mkdir_p(dotdir)

    uml = File.open("#{dotdir}/work_#{dotfilename}",'w')

    uml.puts "@startuml #{pngfilename}"
    uml.puts "title #{title}" unless title.empty?
    uml.puts "skinparam classAttributeIconSize 0"

    font_name=Setting.plugin_redmine_plantuml['font']
    uml.puts "skinparam defaultFontName #{font_name}" if font_name
    uml.puts "skinparam svek true" if use_svek

    uml.close
    return ""
  end

  # =======================================================
  macro :plantuml_body_part do |obj, args|
    
    title = args.shift.sub(/"(.*)"/, "\\1")
    concat_title = title.clone
    if concat_title =~ /^[0-9a-zA-Z_\-]+$/
      concat_title.gsub!(/[\s]+/,'_')
    else
      concat_title = concat_title.hash
    end
    pageid = obj.page.title.hash if obj
    pageid = pageid || "issue"

    filename = "#{obj.page.project.name.hash}_#{pageid}_#{concat_title}"
    dotfilename = "#{filename}.dot"
    pngfilename = "#{filename}.png"
    desc = args.join(',') # ',' in plant uml description

    dotdir = "#{::RAILS_ROOT}/dotfiles"

    return nil unless File.exists?("#{dotdir}/work_#{dotfilename}")

    uml = File.open("#{dotdir}/work_#{dotfilename}",'a')

    annotated_relation = desc.clone
    klass = ""
    last_type = ""
    annotated_relation.gsub!("<br />", "\n")
    annotated_relation.gsub!(/^((.*)\/\/\s+(aggregate|composite|associate))|((class|interface)\s+(\w+))/) do |m|
      st, type, base = $2, $3, $6
      if base.nil?
        st.gsub!(";", "")
        sts = st.split(/\s+/)
        role = sts.pop
        as = sts.pop
        case type
        when "associate"
          uml.puts "#{as} \"#{role}\" <-- #{klass}"
        when "aggregate"
          uml.puts "#{as} \"#{role}\" <--o #{klass}" # klass‚É’l‚ª‚È‚¢‚Æ<-- o ‚É‚È‚é
        when "composite"
          uml.puts "#{as} \"#{role}\" <--* #{klass}"
        end
      else
        klass = base
      end
    end

    class_relation = desc.clone
    klass = ""
    last_type = ""
    class_relation.gsub!("<br />", " ")
    class_relation.gsub!(/((class|interface)\s+(\w+))|([\s]extends\s(\w+(\s*,\s*\w+)*))|([\s]implements\s+(\w+(\s*,\s*\w+)*))/) do |m|
      type, base, cls, inf = $2, $3, $5, $8
      if ! base.nil?
        last_type = type
        klass = base
      elsif ! cls.nil?
        cls.split(",").each do |i|
          uml.puts "#{last_type} #{i}"
          uml.puts "#{i} <|-- #{klass}"
        end
      elsif ! inf.nil?
        inf.split(",").each do |i|
          uml.puts "interface #{i}"
          uml.puts "#{i} <|.. #{klass}"
        end
      end
    end

    desc.clone.each do |lines|
      lines.split("<br />").each do |line|
        line.gsub!(/[\s]((extends|implements)\s([\w,\s]+))/, "")
        line.gsub!(/^[\s]*private[\s]/,"-")
        line.gsub!(/^[\s]*protected[\s]/,"#")
        line.gsub!(/^[\s]*public[\s]/,"+")
        line.gsub!(/&lt;/,"<")
        line.gsub!(/&gt;/,">")
        line.gsub!("<del>", "-")
        line.gsub!("</del>", "-")
        line.gsub!("<p>", "")
        line.gsub!("</p>", "")
        line.gsub!(/\t/, "")
        line.gsub!("<strong>", "*")
        line.gsub!(";", "")
        line.gsub!(/^(.*)\/\/\s+(aggregate|composite|associate).*$/, "")
        line.gsub!(/\/\/.*/, "")

        uml.puts line
      end
    end
    uml.close
    return ""
  end

  # =======================================================
  macro :plantuml_end_of_body do |obj, args|

    title = args.shift.sub(/"(.*)"/, "\\1")
    concat_title = title.clone
    if concat_title =~ /^[0-9a-zA-Z_\-]+$/
      concat_title.gsub!(/[\s]+/,'_')
    else
      concat_title = concat_title.hash
    end
    pageid = obj.page.title.hash if obj
    pageid = pageid || "issue"
    filename = "#{obj.page.project.name.hash}_#{pageid}_#{concat_title}"
    dotfilename = "#{filename}.dot"
    pngfilename = "#{filename}.png"

    dotdir = "#{::RAILS_ROOT}/dotfiles"
    return nil unless File.exists?("#{dotdir}/work_#{dotfilename}")
    uml = File.open("#{dotdir}/work_#{dotfilename}",'a')

    uml.puts "@enduml"
    uml.close

    if !File.exists?("#{::RAILS_ROOT}/public/images/plantuml/#{pngfilename}") ||
        !File.exists?("#{dotdir}/#{dotfilename}") ||
        !FileUtils.identical?("#{dotdir}/#{dotfilename}", "#{dotdir}/work_#{dotfilename}")
      FileUtils.copy("#{dotdir}/work_#{dotfilename}", "#{dotdir}/#{dotfilename}")

      java_home=Setting.plugin_redmine_plantuml['java_home'] 
      plantuml_jar=Setting.plugin_redmine_plantuml['plantuml_jar']
      graphviz_dot=Setting.plugin_redmine_plantuml['dot']

      IO.popen("#{java_home}/bin/java -jar #{plantuml_jar} -charset UTF-8 -graphvizdot \"#{graphviz_dot}\" #{dotdir}/#{dotfilename}", 'r') { |pipe|
        pipe.each { |line|
          puts line
        }
      }
      FileUtils.move("#{dotdir}/#{pngfilename}", "#{::RAILS_ROOT}/public/images/plantuml/#{pngfilename}")
    end
    FileUtils.remove("#{dotdir}/work_#{dotfilename}")
    return "<img \"plantuml diagram - #{title}\" src=\"#{Redmine::Utils::relative_url_root}/images/plantuml/#{pngfilename}?#{Time.now.to_i}\" />"
    
  end
  end
end
