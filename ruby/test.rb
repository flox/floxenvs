#!/usr/bin/env ruby

require 'bundler'
require 'colorize'

# Function to load and test gems
def test_gems(gemfile_path)
  begin
    definition = Bundler::Definition.build(gemfile_path, nil, nil)
  rescue Bundler::GemfileNotFound => e
    puts "Gemfile not found: #{e.message}".red
    return
  end

  definition.dependencies.each do |dependency|
    gem_name = dependency.name
    print "Attempting to load gem: #{gem_name}... "
    begin
      require gem_name
      puts "Success".green
    rescue LoadError => e
      puts "Failed".red
    end
  end
end

# Provide the path to your Gemfile
gemfile_path = 'Gemfile'
test_gems(gemfile_path)

