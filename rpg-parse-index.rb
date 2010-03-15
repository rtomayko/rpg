#!/usr/bin/env ruby
# The `rpg-parse-index` program reads a Rubygems "modern index" stream on
# standard input and writes a parseable version of the index data on standard
# output.
#
# About Rubygems Spec Indexes
# ---------------------------
#
# Rubygems spec index files are built with the `gem generate_index` command
# and are typically served from gem repositories at predefined locations. For
# example, the canonical Rubygems spec index lives at:
#
#     http://rubygems.org/specs.4.8.gz
#
# Output Format Details
# ---------------------
#
# Spec indexes are gzip compressed. This program assumes uncompressed data
# on standard input. You will need to pipe the file off the network through
# `gzip -dc` before feeding it in here. To see the main release spec index
# on stdout, you might:
#
#     curl -Ls http://rubygems.org/specs.4.8.gz | gzip -dc                                  |
#     rpg-parse-index
#
# A randomly selected bit of output from the above command:
#
#     ...
#     desert 0.5.3 ruby
#     desert 0.5.2 ruby
#     desutwo 0.0.3 ruby
#     detective 0.3.0 ruby
#     detective 0.2.0 ruby
#     detective 0.1.0 ruby
#     detective 0.0.0 ruby
#     devball 0.7 ruby
#     devball 0.6 ruby
#     devball 0.5 ruby
#     devball 0.4 ruby
#     devball 0.3 ruby
#     ...
#
# The format is:
#
#     <name> <SP> <version> <SP> <platform> <LF>
#
# Where `<name>` and `<version>` are obvious and `<platform>` is an open field
# that can be anything. Popular `<platform>` values at time of writing are:
#
#     $ rpg-parse-index < spec.4.8 | cut -f 3 | sort | uniq -c | sort -rn
#     48766 ruby
#       363 mswin32
#       265 x86-mswin32-60
#       176 java
#        95 x86-mingw32
#        90 x86-linux
#        87 x86-mswin32
#        52 i386-mswin32
#        46 darwin
#        32 universal-darwin-9
#        30 jruby
#     ...
#
# Version Sorting
# ---------------
#
# Another important attribute of the output generated from this command is that
# it's sorted based on Rubygems version comparison rules. The first line of
# output for a given package is that package's "most recent" version. Adjacent
# lines are successively less recent.
#
# This allows the output from this command to be used with `sort -u` and
# `uniq(1)` to generate a most recent index. Utilities like `join(1)` may also
# be used on the output to perform relational operations with other package
# lists having the same format.
USAGE = <<BANNER
Usage: rpg-parse-index
Convert modern gemspec index to parseable text format.

Reads a gemspec index on standard input and writes a formatted version on
standard output. Output is sorted by package name and reverse version number.

This is a low level command used by the rpg package index machinery.
BANNER

if ARGV.include?('--help') || STDIN.tty?
  puts USAGE
  exit 2
end

# Main Program Logic
# ------------------

# Fake out `Marshal` by creating a mock Gem module and Version class. This
# removes the reliance on Rubygems and speeds things up considerably.
Object.send :remove_const, :Gem if Object.const_defined?(:Gem)
Kernel.send :remove_const, :Gem if Kernel.const_defined?(:Gem)

module Gem
  class Version < Array
    def marshal_load(data)
      @string = data.first
      replace @string.split('.')
      map! { |p| p.to_i }
    end

    def to_s
      @string
    end
  end
end

# Load packages in from STDIN.
packages = Marshal.load(STDIN)

# Sort packages by name and then reverse version number.
#
# TODO prelease version sorting.
packages.sort! do |(n1,v1,p1),(n2,v2,p2)|
  if (cmp = (n1 <=> n2)) == 0
    v2 <=> v1
  else
    cmp
  end
end

# Finally, run over the sorted list and write a line of output for each package.
packages.each do |name,version,platform|
  puts "#{name} #{version} #{platform}"
end

# vim: tw=80 sw=2 ts=2 sts=0 expandtab
