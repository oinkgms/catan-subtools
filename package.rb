require 'date'
require 'rake/clean'

def extract_version(projpath)
  File.open("#{projpath}/ProjectSettings/ProjectVersion.txt", "r").readlines.each do |l|
    if l =~ /\Am_EditorVersion:\s+(.+)\Z/
      return $1
    end
  end
  ''
end

RAKE = 'rake'
GIT = 'git'
PROJECT_PATH = ENV['PROJECT_PATH'] || (File.expand_path(Dir.pwd) + "/unityproj")
UNITY_VERSION = extract_version(PROJECT_PATH)
UNITY_DIR ||= "/Applications/Unity#{UNITY_VERSION}"
UNITY_APP = "#{UNITY_DIR}/Unity.app/Contents/MacOS/Unity"
MDTOOL = "#{UNITY_DIR}/MonoDevelop.app/Contents/MacOS/mdtool"
PAGER = 'less'
UNITY_LOG = '~/Library/Logs/Unity/Editor.log'

raise "must define PACKAGE_NAME" if not Object.const_defined?(:PACKAGE_NAME) or PACKAGE_NAME.nil? or PACKAGE_NAME.empty?
EDITOR_ROOT = "Editor/#{PACKAGE_NAME}"
PLUGINS_ROOT = "Plugins/#{PACKAGE_NAME}"
BRANCH_NAME = "renew-#{PACKAGE_NAME.downcase}"
UNITYPACKAGE_PATH = "#{PACKAGE_NAME}_#{DateTime.now.strftime('%Y%m%d_%H%M')}.unitypackage"
ADDITIONAL_EXPORT_PATH ||= ''

CLEAN.include(FileList['*.unitypackage'])

IMPORT_SETTING = '.import.txt'
IMPORT_TMPDIR = '.import'
IMPORT_PROJECTS = []
if File.exist?(IMPORT_SETTING)
  File.open(IMPORT_SETTING, 'r').read.split(/\r?\n/).each do |l|
    l.strip!
    if l !~ /^#/ and l =~ /([^\/]+)\.git$/
      IMPORT_PROJECTS << [l, "#{IMPORT_TMPDIR}/#{$1}", $1]
    end
  end
  #p IMPORT_PROJECTS
end





desc "export UnityPackage"
task :export do
  sh "#{UNITY_APP} -batchmode -projectPath #{PROJECT_PATH} -exportPackage Assets/#{EDITOR_ROOT} Assets/#{PLUGINS_ROOT} #{ADDITIONAL_EXPORT_PATH} ../#{UNITYPACKAGE_PATH} -quit"
end

desc "show Unity Editor's log"
task :showlog do
  sh "#{PAGER} #{UNITY_LOG}"
end

namespace :hidden do
  task :import_to do
    pkgs = FileList['*.unitypackage'].sort
    latest = File.expand_path(pkgs.last)
    sh "#{UNITY_APP} -batchmode -projectPath #{File.expand_path(PROJECT_PATH)} -importPackage #{latest} -quit"
  end
end

directory IMPORT_TMPDIR
namespace :pull do
  IMPORT_PROJECTS.each do |proj|
    u = proj[0]
    d = proj[1]
    n = proj[2]
    desc "pull:#{n}"
    task n => [IMPORT_TMPDIR] do
      unless File.exist?(d)
        cd IMPORT_TMPDIR do
          sh "#{GIT} clone #{u}"
        end
      end
      cd d do
        sh "#{GIT} checkout master"
        sh "#{GIT} pull origin master"
        branches = `#{GIT} branch`.split(/\n/).map { |l| l.strip.downcase }
        if branches.include?(BRANCH_NAME)
          sh "#{GIT} checkout #{BRANCH_NAME}"
          sh "#{GIT} rebase master"
        else
          sh "#{GIT} checkout -b #{BRANCH_NAME}"
        end
      end
    end
  end
end
desc "pull all projects"
task :pull_all => IMPORT_PROJECTS.map { |proj| "pull:#{proj[2]}" }

namespace :import do
  IMPORT_PROJECTS.each do |proj|
    d = proj[1]
    n = proj[2]
    desc "import:#{n}"
    task n do
      sh "#{RAKE} hidden:import_to PROJECT_PATH=#{d}/client"
    end
  end
end
desc "import package to all projects"
task :import_all => IMPORT_PROJECTS.map { |proj| "import:#{proj[2]}" }

namespace :commit do
  IMPORT_PROJECTS.each do |proj|
    d = proj[1]
    n = proj[2]
    desc "commit:#{n}"
    task n do
      cd d do
        sh "#{GIT} add ."
        sh "#{GIT} commit -m 'renew #{PACKAGE_NAME}'"
      end
    end
  end
end
desc "commit all projects"
task :commit_all => IMPORT_PROJECTS.map { |proj| "commit:#{proj[2]}" }

namespace :push do
  IMPORT_PROJECTS.each do |proj|
    d = proj[1]
    n = proj[2]
    desc "push:#{n}"
    task n do
      cd d do
        sh "#{GIT} push origin #{BRANCH_NAME}"
      end
    end
  end
end
desc "push all projects"
task :push_all => IMPORT_PROJECTS.map { |proj| "push:#{proj[2]}" }

namespace :update do
  IMPORT_PROJECTS.each do |proj|
    n = proj[2]
    desc "do pull:#{n}, import:#{n}, commit:#{n}"
    task n => ["pull:#{n}", "import:#{n}", "commit:#{n}"]
  end
end
desc "do pull_all, import_all, commit_all"
task :update_all => [:pull_all, :import_all, :commit_all]


