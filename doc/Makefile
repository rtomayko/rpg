.POSIX:

include ../config.mk

MANPAGES     = rpg-solve.1
MANPAGESHTML = rpg-solve.1.html
RONN = ronn --manual="RPG MANUAL" --organization="Ryan Tomayko"

all:: man

man: $(MANPAGES) $(MANPAGESHTML)

.SUFFIXES: .ronn .html

.ronn:
	printf "%13s  %-30s" "[ROFF]" "$@"
	ronn $< > $@+
	mv $@+ $@
	printf "       OK\n"

.ronn.html:
	printf "%13s  %-30s" "[HTML]" "$@"
	ronn -5 $< > $@+
	mv $@+ $@
	printf "       OK\n"

clean:
	rm -vf $(MANPAGES)
	rm -vf $(MANPAGESHTML)

.SILENT:

.PHONY: clean
