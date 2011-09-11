#!/usr/bin/env ruby
# Read YAML gemspecs given as arguments or on standard input and write
# rpg formatted spec hierarchies to the package database.
USAGE = <<BANNER
Usage: rpg-package-spec <spec>
       rpg-package-spec [-i|--import] <spec> ...
Deal with gemspecs.

In the first form, read gemspec YAML from a gemspec or gem file and write
parseable output to standard output. In the second form, read multiple
gemspec files into the package database.

Options
  -i, --import     Load gemspec data into the package database. No output
                   is written. Multiple files may be specified.

This is a low level command used by the rpg package database machinery.
BANNER

# Bail out with no arguments or --help.
if ARGV.empty?
  puts USAGE
  exit 2
elsif ARGV.include?('--help')
  puts USAGE
  exit 0
end

# Re-execute through rpg if the environment isn't right.
exec "rpg", "package-spec", *ARGV if ENV['RPGDB'].to_s == ''

# Figure out if we're in import mode or print formatted output mode.
if ['-i', '--import'].include?(ARGV.first)
  ARGV.shift
  import_mode = true
else
  import_mode = false
end

# Load the YAML in from file or extract from gem using `rpg-unpack(1)`.
require 'ostruct'
require 'yaml'

ARGV.each do |file|
  yaml =
    if file =~ /\.gem$/
      `rpg unpack -cm '#{file}'`
    else
      File.read(file)
    end
  doc = YAML.load(yaml)

  # Turn this fucker into something sensible.
  spec = doc.ivars.dup
  spec['version'] = spec['version'].ivars['version']
  spec['dependencies'] =
    spec['dependencies'].map do |dep|
      vars = dep.ivars
      [
        vars['name'],
        vars['type'] || 'runtime',
        vars['version_requirements'].ivars['requirements'].map do |op,vers|
          vers = vers.ivars['version']
          [op, vers]
        end
      ]
    end
  spec['date'] =
    case spec['date']
    when Time; spec['date'].utc.strftime('%Y-%m-%d')
    when Date; spec['date'].to_s
    when String
      # Some date formats are not parsed by YAML despite being legitimate;
      # e.g. 2011-08-25 00:00:00.000000000Z.
      # Use Time.parse to parse such dates.
      # Sadly, it looks like Time.parse will silently accept any garbage
      # fed to it, meaning truly invalid input is unlikely to be caught.
      require 'time'
      Time.parse(spec['date']).utc.strftime('%Y-%m-%d')
    else fail "unexpected date value: #{spec['date'].inspect}"
    end
  spec.reject! { |k,v| v.respond_to?(:ivars) }

  if import_mode

    # Grab the package name and version.
    package = spec['name']
    version = spec['version']
    package_dir = "#{ENV['RPGDB']}/#{package}/#{version}"

    if !File.directory?(package_dir)
      Dir.mkdir File.dirname(package_dir) rescue nil
      Dir.mkdir package_dir rescue nil
      if !File.directory?(package_dir)
        abort "#{File.basename($0)}: package directory missing."
      end
    end

    package_write =
      lambda do |file, value|
        File.open("#{package_dir}/#{file}", 'wb') do |fd|
          fd.puts(value.to_s)
        end
      end

    %w[name version date homepage platform email bindir summary description].each do |key|
      package_write.call key, spec[key]
    end

    %w[authors files extensions executables test_files require_paths].each do |key|
      next if spec[key].nil?
      package_write.call key, spec[key].join("\n")
    end

    File.open "#{package_dir}/dependencies", 'wb' do |fd|
      spec['dependencies'].each do |name, type, reqs|
        reqs.each do |op, vers|
          fd.puts "#{type} #{name} #{op} #{vers}"
        end
      end
    end

  else

    %w[name version date homepage platform email bindir].each do |key|
      puts "#{key}: #{spec[key]}"
    end

    puts "rdoc: #{spec['rdoc_options'].join(' ')}"

    %w[authors files extensions executables test_files require_paths].each do |key|
      next if spec[key].nil?
      label = key.chomp('s')
      label = 'test' if key == 'test_files'
      label = 'lib' if key == 'require_paths'
      spec[key].each do |line|
        puts "#{label}: #{line}"
      end
    end

    spec['dependencies'].each do |name, type, reqs|
      reqs.each do |op, vers|
        puts "dependency: #{type} #{name} #{op} #{vers}"
      end
    end

  end
end
