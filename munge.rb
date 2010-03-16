#!/usr/bin/env ruby
# Usage: munge SYMBOL FILE
# Super simple file munger. Reads stdin and replaces SYMBOL with the
# contents of FILE before writing it to stdout.

data = STDIN.read
data.gsub!(ARGV[0]) { File.read(ARGV[1]) }
STDOUT.write data
