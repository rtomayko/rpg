Dependency Solving
==================

## Stuff

#### Package Lists

A package list is a simple text file where each line specifies a package
matching rule. It looks like this:

    <source> <SP> <package> <SP> <verspec> <SP> <version> <NL>

The `<package>` is the package name, `<version>` is the package version, and
`<verspec>` is one of: `<`, `<=`, `=`, `>=`, or `>`. The `<source>` field
specifies where the requirement originated. This can be a package name (in case
of dependencies), `~user` (in case of user install), or `-` to denote the
requirement has no source or the source is unimportant.

Example:

    ~user rails > 2.2
    ~user sinatra >= 0
    rails activesupport = 2.2
    rails activerecord = 2.2
    sinatra rack >= 1.0
    rails rack >= 1.0.1

#### Package Indexes

A package index is a simple text file where each line specifies a concrete
package name and version. It looks like this:

    <package> <SP> <version> <NL>

Package indexes are usually sorted by `<package>` and then reverse by
`<version>`. This allows efficient lookups for many packages in a single pass
over a file.

## How Dependencies and Conflicts are Solved

### 1. Build Master Package List

Build a standard format package list from all packages provided on the command
line with `rpg-package-list(1)`. It looks like this, remember:

    ~user <package> <verspec> <version>

This is the _master package list_.

### 1.5 Build Installed Package Index and Dependency Package List

Build a package index for all packages currently installed on the system with,
e.g., `rpg-package-index(1)`. This is the _installed package index_.

Build a package list from all dependency lists of all installed packages
*except* those that are included in the master package list. This is called the
_existing dependency package list_

    <source> <package> <verspec> <version>

It's important that lines whose `<source>` is a package existing in the master
package list are excluded. Otherwise, the dependency rules for already installed
packages will constrain the resolver.

### 2. Resolve Package Versions

Concatenate the master package list and the installed package list through `rpg-solve(1)` to find the best versions of
each package based on its requirements.  The output is a concrete package index
called the *solved package index*:

    rails 2.3.1
    sinatra 0.9.6

The package index files passed into `rpg-solve` are as follows:

  1. The *solved package index*
  2. The *installed package index*
  3. The *release package index*

If `rpg-install` is in upgrade mode, the *installed package index*
is not used. This causes the all package rules to be resolved against
the *release package index*, resulting in all packages included in the
*master package list* being upgraded to the most recent compatible
version.

### 3. Register Packages

Fetch each package in the *solved package index* with `rpg-fetch(1)` and
register the package version in the package database with `rpg-register(1)`.

__NOTE:__ `rpg-register(1)` just loads the packages spec data into the database.
It doesn't install anything.

### 4. Resolve Package Dependencies

For each package resolved in step 2, add that package's dependencies to the
master package list. Now maybe the master package list looks like this:

    @user rails > 2.2
    @user sinatra >= 0
    sinatra rack > 1.0
    rails rack >= 1.0.1
    rails activerecord = 2.2

Notice how there can be multiple entries for a single package in the package
list. `rpg-solve(1)` returns the best match for a package given all the
requirements.

### 5. GOTO 2

If the master package list at step 4 has changed from the master package list at
step 2, go back and continue from step 2: resolve the new master package list
down to a concrete package index, resolve dependencies, and come back here.

If the master package did not change on this pass, continue on to the next step.

### 6. Conflict Resolution

A number of exceptional conditions can arise at this point:

  1. A package specified by the user or by dependency does not exist in any
     package index. This could be due to a stale index or because a package
     name is wrong.

  2. A package version meeting all of the criteria specified by the master
     package list and the existing dependency package list could not be found.
     This could be due to conflicting dependency specifications in multiple
     packages.

In either of the cases mentioned above, the `rpg-solve(1)` program will output
a record whose version is "-". The front-end is then responsible for presenting
this list to the user in some way. The user should be able to choose what should
happen.

  1. Change the version of the package
  2. Force the package to be installed anyway (what package? what version?)
  3. Abort the installation
