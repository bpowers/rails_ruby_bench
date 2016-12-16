#!/usr/bin/env ruby

require "json"

CUR_DIRECTORY = File.dirname(__FILE__)

SETTINGS = JSON.parse File.read("setup.json")

# TODO:
# * Review Postgres setup - complete?
# * Mailcatcher
# * create initializer to bundle jquery-include.js in assets?

def clone_or_update_repo(repo_url, work_dir)
  if File.exist?(work_dir)
    Dir.chdir(work_dir) do
      system("git pull") || raise("Couldn't 'git pull' in #{work_dir}!")
    end
  else
    system("git clone #{repo_url} #{work_dir}") || raise("Couldn't 'git clone' into #{work_dir}!")
  end

end

DISCOURSE_DIR = File.join(CUR_DIRECTORY, "work", "discourse")
RUBY_DIR = File.join(CUR_DIRECTORY, "work", "ruby")

clone_or_update_repo SETTINGS["discourse_git_url"], DISCOURSE_DIR
clone_or_update_repo SETTINGS["ruby_git_url"], RUBY_DIR

system("cd #{DISCOURSE_DIR} && bundle") || raise("Failed running bundler in #{DISCOURSE_DIR}")

Dir.chdir(RUBY_DIR) do
  unless File.exists?("configure")
    system("autoconf") || raise("Couldn't run autoconf in #{RUBY_DIR}!")
  end
  unless File.exists?("Makefile")
    system("./configure") || raise("Couldn't run configure in #{RUBY_DIR}!")
  end
  system("make") || raise("Make failed in #{RUBY_DIR}!")
end

Dir.chdir(DISCOURSE_DIR) do
  system("createuser discourse") # Don't check for failure
  system("psql -d postgres -c \"create database discourse owner discourse encoding 'UTF8' TEMPLATE template0;\"") # Don't check for failure
  system("RAILS_ENV=profile rake db:create")  # Don't check for failure
  system("RAILS_ENV=profile rake db:migrate") || raise("Failed running 'rake db:migrate' in #{DISCOURSE_DIR}!")
  system("RAILS_ENV=profile rake assets:precompile") || raise("Failed running 'rake assets:precompile' in #{DISCOURSE_DIR}!")
end
