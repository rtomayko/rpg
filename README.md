rpg - manages gem packages. quickly.
====================================

This is rpg, an experimental Ruby package management utility for unix based on
the Rubygems packaging format and repository protocol. rpg installs Ruby
packages distributed from rubygems.org to a shared library directory with full
support for dependency resolution, native extension compilation, and package
upgrades. It's quite fast.

`rpg` can be thought of as a non-compatible alternative to the `gem` command
shipped with Rubygems. Most commonly used gem operations are available in `rpg`,
but in ways that are a bit different from the `gem` command -- both in interface
and implementation. See the *VERSUS RUBYGEMS* section below for details on these
differences.

rpg and Rubygems can co-exist on a system, though Rubygems is not required for
rpg to operate. Packages installed with `rpg` override packages installed with
the `gem` command.

Please direct rpg related discussion to the rpg mailing list:
[ruby-rpg@googlegroups.com](http://groups.google.com/group/ruby-rpg).

Status
------

*Update: This repository is no longer actively maintained by @rtomayko. Issues and PRs documenting current issues have been intentionally left open for informational purposes.*

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

See the `HACKING` file for information on setting up a temporary working
environment for development, or if you just want to try out rpg in a sandbox
before installing.

Basic Usage
-----------

For a list of commands and basic program usage:

    $ rpg --help
    Usage: rpg [-vx] [-c <path>] <command> [<args>...]
    Manage gem packages, quickly.

    The most commonly used rpg commands are:
      config           Show or edit rpg configuration
      dependencies     Show dependency information for a package or all packages
      install          Install a package from file or remote repository
      list             Show status of local packages vs. respository
      steal            Transplant packages from Rubygems into rpg environment
      sync             Sync the package index with repository
      outdated         List packages with a newer version
      uninstall        Uninstall packages from local system
      upgrade          Upgrade installed packages to latest version

    Options
      -c <path>        Read rcfile at <path> instead of standard rpgrc locations
      -v               Enable verbose logging to stderr
      -q               Disable verbose logging to stderr
      -x               Enable shell tracing to stderr (extremely verbose)

    See `rpg help <command>' for more information on a specific command.

Installing one or more packages and all package dependencies:

    $ rpg install rails
                 sync: package index not found. retrieving now.
                 sync: complete. 11894 packages available.
              prepare: calculating dependencies for rails ...
                fetch: rails 2.3.5
                fetch: activeresource 2.3.5
                fetch: actionmailer 2.3.5
                fetch: actionpack 2.3.5
                fetch: activesupport 2.3.5
                fetch: rake 0.8.7
                fetch: activerecord 2.3.5
                fetch: rack 1.0.1
              prepare: 0 of 8 packages already installed and up to date
              install: installing 8 packages
      package-install: actionmailer 2.3.5
      package-install: actionpack 2.3.5
      package-install: activerecord 2.3.5
      package-install: activeresource 2.3.5
      package-install: activesupport 2.3.5
      package-install: rack 1.0.1
      package-install: rails 2.3.5
      package-install: rake 0.8.7
              install: installation complete

Listing currently installed packages and their versions:

    $ rpg list
    actionmailer 2.3.5
    actionpack 2.3.5
    activerecord 2.3.5
    activeresource 2.3.5
    activesupport 2.3.5
    rack 1.0.1
    rails 2.3.5
    rake 0.8.7

Listing currently installed packages with information about available package
versions:

    $ rpg list -l
      actionmailer                        2.3.5        2.3.5
      actionpack                          2.3.5        2.3.5
      activerecord                        2.3.5        2.3.5
      activeresource                      2.3.5        2.3.5
      activesupport                       2.3.5        2.3.5
    * rack                                1.0.1        1.1.0
      rails                               2.3.5        2.3.5
      rake                                0.8.7        0.8.7

Listing only outdated packages:

    $ rpg outdated
    rack                                1.0.1        1.1.0

Uninstalling one or more packages:

    $ rpg uninstall rails actionmailer

Listing package dependencies recursively:

    $ rpg dependencies -r rails
    actionmailer = 2.3.5
    actionpack = 2.3.5
    activerecord = 2.3.5
    activeresource = 2.3.5
    activesupport = 2.3.5
    rack ~> 1.0.0
    rake >= 0.8.3

Or, in a tree:

    $ rpg dependencies -t rails
    rake >= 0.8.3
    activesupport = 2.3.5
    activerecord = 2.3.5
    |-- activesupport = 2.3.5
    actionpack = 2.3.5
    |-- activesupport = 2.3.5
    |-- rack ~> 1.0.0
    actionmailer = 2.3.5
    |-- actionpack = 2.3.5
    |   |-- activesupport = 2.3.5
    |   |-- rack ~> 1.0.0
    activeresource = 2.3.5
    |-- activesupport = 2.3.5

To get a feel for rpg performance vs. the gem command when install packages with
complex dependency graphs:

    $ time rpg install merb
    $ time gem install merb

Versus Rubygems
---------------

Similarities with the `gem` command:

  * `rpg` uses rubygems.org as its package repository and gem
    files as its package format. Installing from other sources is not yet
    supported, but is likely to be added in the near future.

  * `rpg` supports dependency resolution using the information
    included in a gem's specification metadata.

  * `rpg` supports building and installing native / dynamic library
    extensions.

  * `rpg` has a rich set of commands for installing, upgrading,
    and uninstalling packages; listing installed, available, and outdated
    packages; and utilities for unpacking gem files and inspecting gem
    specifications.

  * "rpg" is made of exactly three characters.

Differences from the `gem` command:

  * `rpg` organizes the files it installs by file type, not by package. For
    instance, Ruby library files are placed directly under a single
    `lib` directory (the currently active `site_ruby` directory by default),
    executables under `/usr/local/bin` (configurable), manpages under
    `/usr/local/share/man`, etc.

  * `rpg` is not capable of installing multiple versions of the same package
    into a single rpg environment -- the package's files would overwrite each
    other. All version conflicts must be resolved at install time.

  * `rpg` is similarly unable to install more than one package owning the
    same file under Ruby libdir. (Currently `rpg` will install such packages
    anyway, with later installed packages overwriting files installed by
    earlier installed packages.)

  * `rpg` has no runtime component (e.g., `require 'rubygems'`). Because all
    library files are placed under a common `lib` directory, and because package
    versions are sussed at install time, there's no need for a component to
    select which packages are active at runtime.

  * `rpg` installs packages in two stages: 1.) fetch package files
    and resolve dependencies, and 2.) install package contents. This allows
    for staged/later installs and conflict detection before install.

  * `rpg`'s installed package database is filesystem based, (will be) documented,
    and is built for extension.

  * `rpg` is written primarily in POSIX shell and requires a unix environment.

  * `rpg` does not provide commands for building gems or running gem servers.

  * `rpg` outperforms the gem command in many ways. Most comparable operations
    complete in at least one order of magnitude less time.

About
-----

rpg's design is inspired by a variety of existing tools. The `gem` command's
basic UI, package format, and repository structure are heavily borrowed from
or used verbatim.

Many of the ideas -- and maybe even some code -- were taken from
[Rip](http://defunkt.github.com/rip/). That's understating it, really. rpg
started out just a couple of loose shell scripts to experiment with ideas for
integrating gem package and gem dependency support into rip. The plan was to
port them over to Ruby and into Rip if they panned out. Within a few days, I had
a more or less entire implementation of Rubygems's gem command in POSIX shell
staring back at me and it was *fast*. Some of rpg's features may make their way
into Rip (the Ruby portions that read release indexes and gemspecs should be
useful at least).

Debian's apt and dpkg, FreeBSD's ports system, and Redhat/Fedora's yum all
influenced rpg's design in various ways.

Git's overall design influenced rpg significantly. Git's internal project
organization is a template for writing moderate sized systems using many small
specialized programs. Its granular use of the filesystem as a database (the
`.git/refs` and `.git/objects` hierarchies, especially) informed much of rpg's
package database design.

Copying
-------

Copyright (c) 2010 by [Ryan Tomayko](http://tomayko.com/about)

This is Free Software distributed under the terms of the MIT license.
See the `COPYING` file for license rights and limitations.
