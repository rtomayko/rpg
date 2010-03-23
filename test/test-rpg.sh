# 
. ./test-lib.sh

desc 'main rpg command tests'
setup

succeeds 'rpg'
succeeds 'rpg --help'
fails 'passing invalid arguments' 'rpg -X'

succeeds 'enabling verbose mode with -v' 'rpg -v help'
succeeds 'enabling trace mode with -x'   'rpg -x help'

succeeds 'rpg config'
succeeds 'rpg env'
succeeds 'rpg sync'
succeeds 'rpg list'
succeeds 'rpg prepare rails'
succeeds 'rpg install rails'
succeeds 'rpg fsck'
