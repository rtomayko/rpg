rpg - manages gem packages. quickly.
====================================

This is rpg, an experimental Ruby package management utility for unix based on
the Rubygems packaging format and repository protocol. rpg installs Ruby
packages distributed from rubygems.org to a shared library directory with full
support for dependency resolution, native extension compilation, and package
upgrades.

rpg can be thought of as a non-compatible alternative to the gem command shipped
with Rubygems. Most commonly used gem operations are available in rpg, but in
ways that are a bit different from the gem command -- both in interface and
implementation. See the *VERSUS RUBYGEMS* section below for details on these
differences.

rpg and Rubygems can co-exist on a system, though Rubygems is not required for
rpg to operate. Packages installed with rpg override packages installed with the
gem command.

Status
------

Experimental. Using rpg with system rubys is not yet recommended. Suggested use
is with rvm or custom, non-system ruby builds. See the `KNOWN-ISSUES` file for a
list of potential gotchas and general annoyances.

IMPORTANT: In its default configuration, rpg installs library files under the
active Ruby interpreter's `vendor_ruby` or `site_ruby` directory. The `rpg
config` command outputs the current destination installation paths -- use it to
verify the active configuration before performing destructive operations.

Installing
----------

rpg is installed with the conventional `./configure && make && make install`
process. See the `INSTALLING` file for information on obtaining the latest
release and variations on the basic installation.

See the `HACKING` file for directions on setting up a temporary working
environment for development, or if you just want to try out rpg in a sandbox
before installing.

Versus Rubygems
---------------

  * Like gem, rpg uses rubygems.org as its package repository and gem
    files as its package format. Installing from other sources is not yet
    supported, but is likely to be added in the near future.

  * Like gem, rpg supports dependency resolution using the information
    included in a gem's specification metadata.

  * Like gem, rpg supports building and installing native / dynamic library
    extensions.

  * Like gem, rpg has a rich set of commands for installing, upgrading,
    and uninstalling packages; listing installed, available, and outdated
    packages; and utilities for unpacking gem files and inspecting gem
    specifications.

  * Like gem, rpg is made up of exactly three characters.

  * Unlike gem, rpg organizes the files it installs by file type, not by
    package. For instance, Ruby library files are placed directly under a
    single `lib` directory (the currently active `site_ruby` directory by
    default), executables under `/usr/local/bin` (configurable), manpages
    under `/usr/local/share/man`, etc.

  * Unlike gem, rpg is not capable of installing multiple versions of the
    same package into a single rpg environment -- the package's files would
    overwrite each other. All version conflicts must be resolved at install
    time.

  * Unlike gem, rpg has no runtime component (e.g., `require 'rubygems'`).
    Because all library files are placed under a common `lib` directory, and
    because package versions are sussed at install time, there's no need for
    a component to select which packages are active at runtime.

  * Unlike gem, rpg installs packages in two stages: 1.) fetch package files
    and resolve dependencies, and 2.) install package contents. This allows
    for staged/later installs and conflict detection before install.

  * Unlike gem, rpg's installed package database is filesystem based,
    (will be) documented, and is built for extension.

  * Unlike gem, rpg is written primarily in POSIX shell and requires a unix
    environment.

  * Unlike gem, rpg does not provide commands for building gems or running
    gem servers.

  * rpg outperforms the gem command in many ways. Most comparable
    operations complete in at least one order of magnitude less time.

About
-----

rpg's design is inspired by a variety of existing tools. Rubygems itself gets
many things right in UI, and you can't argue with the popularity of the package
format and repository within the Ruby community.

Many of the ideas -- and maybe even some code -- were taken from
[Rip](http://defunkt.github.com/rip/). That's understating it, really. rpg
started out just a couple of loose shell scripts to experiment with potential
ideas for integrating gem package and gem dependency support into rip. The plan
was to port them over to Ruby and into Rip if they panned out. Within a few
days, I had a more or less entire implementation of Rubygems's gem command in
POSIX shell staring back at me and it was *fast*. I will very likely propose
many of the ideas in rpg be taken into Rip. Surely the Ruby portions of rpg that
read release indexes and gemspecs could be useful at least.

Debian's apt and dpkg, FreeBSD's ports system, and Redhat/Fedora's yum all
influenced rpg's design in various ways.

Git's overall design influenced rpg significantly. Git's internal project
organization provides a roadmap for writing moderate sized systems using many
small specialized programs. Its granular use of the filesystem as a database
(the .git/refs and .git/objects hierarchies, especially) informed much of rpg's
package database design.

Copying
-------

Copyright (c) 2010 by Ryan Tomayko <http://tomayko.com/about>

This is Free Software distributed under the terms of the MIT license.
See the `COPYING` file for license rights and limitations.
