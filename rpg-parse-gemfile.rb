#!/usr/bin/env ruby
# The `rpg-parse-gemfile` program reads a Bundler Gemfile and writes a
# list of packages on standard output suitable for feeding to `rpg-install`.
#
# Usage
# -----
#
# Given a project with a Gemfile, it is possible to install its dependencies
# by running:
#
#     rpg install $(rpg parse-gemfile /path/to/Gemfile)
#
# Caveats
# -------
#
# At this time only top-level gem statements are actually supported.
# All options are ignored. All groups other than the top-level group are
# ignored. All other statements are ignored.
#
# Bundler uses dependency declarations in all groups when resolving
# dependencies, even in groups that are not being installed.
# See http://yehudakatz.com/2010/05/09/the-how-and-why-of-bundler-groups/,
# section "Consistency". This may render a Gemfile unresolvable if, for
# example, the test group specifies conflicting or broken dependencies, even
# for users who don't want to install the test group. rpg ignores all groups
# that are not being installed during dependency resolution. As a consequence,
# rpg and Bundler may install different sets of packages from the same Gemfile.
USAGE = <<BANNER
Usage: rpg-parse-gemfile [PATH]
Convert Bundler Gemfile to a list of packages suitable for installation.

Reads a Gemfile located at specified PATH, or standard input, and writes
a list of packages suitable for feeding to rpg-install on standard output.

Try: rpg install $(rpg parse-gemfile /path/to/Gemfile)
BANNER

if ARGV.include?('--help') || ARGV.length > 1 || ARGV.empty? && STDIN.tty?
  puts USAGE
  exit 2
end

class GemfileParser
  def initialize
    @packages = []
  end
  
  def parse(gemfile_text, file=nil)
    eval(gemfile_text, nil, file)
  end
  
  def method_missing(name, *args)
    #puts "Ignoring #{name}"
  end
  
  def gem(name, *args)
    unless args.first.is_a?(Hash)
      version = args.shift
    end
    options = args.shift || {}
    @packages << {
      :name => name, :version => version, :options => options,
      :group => @in_group,
    }
  end
  
  def group(name)
    if @in_group
      raise ArgumentError, 'Nested groups are not supported'
    end
    @in_group = name
    yield
    @in_group = nil
  end
  
  def print
    @packages.each do |package|
      next if package[:group]
      version_op, version_value = canonicalize_version(package[:version])
      puts "#{package[:name]} #{version_op} #{version_value}"
    end
  end
  
  def canonicalize_version(version)
    if version.nil?
      return ['>=', '0']
    end
    unless version =~ /^([>=~]*)(\d.+)$/
      raise ArgumentError, "Invalid version specification: #{version}"
    end
    op, value = $1, $2
    if op.empty?
      op = '='
    end
    return [op, value]
  end
end

if (file = ARGV.shift) && file != '-'
  text = File.read(file)
else
  file = '<stdin>'
  text = STDIN.read
end

parser = GemfileParser.new
parser.parse(text, file)
parser.print
