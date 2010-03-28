# rpg makefile
.POSIX:

# Default make target
all::

include config.mk

NAME = rpg
TARNAME = $(NAME)
SHELL = /bin/sh

CFLAGS = -Wall -pedantic

# ---- END OF CONFIGURATION ----

all:: build

DOCHTML = \
	rpg-sh-setup.html rpg.html rpg-fetch.html \
	rpg-sync.html rpg-upgrade.html rpg-outdated.html \
	rpg-package-install.html rpg-package-spec.html rpg-parse-index.html \
	rpg-list.html

PROGRAMPROGRAMS = \
	rpg-config rpg-fetch rpg-install rpg-uninstall rpg-build \
	rpg-env rpg-sync rpg-resolve rpg-upgrade rpg-steal rpg-fsck rpg-list \
	rpg-outdated rpg-package-list rpg-package-register rpg-package-install \
	rpg-unpack rpg-package-spec rpg-parse-index rpg-shit-list \
	rpg-prepare rpg-complete rpg-help rpg-package-index rpg-dependencies \
	rpg-leaves rpg-manifest rpg-solve rpg-diff

DEADPROGRAMS = \
	rpg-update rpg-status rpg-parse-package-list rpg-version-test

OBJECTS = \
	strnatcmp.o rpg-solve.o

USERPROGRAMS = rpg rpg-sh-setup
PROGRAMS     = $(USERPROGRAMS) $(PROGRAMPROGRAMS)

.SUFFIXES: .sh .rb .html .c .o

.sh:
	printf "%13s  %-30s" "[SH]" "$@"
	$(SHELL) -n $<
	rm -f $@
	$(RUBY) ./munge.rb __RPGCONFIG__ config.sh <$< >$@+
	chmod a-w+x $@+
	mv $@+ $@
	printf "       OK\n"

.sh.html:
	printf "%13s  %-30s" "[SHOCCO]" "$@"
	shocco $< > $@
	printf "       OK\n"

.rb:
	printf "%13s  %-30s" "[RUBY]" "$@"
	ruby -c $< >/dev/null
	rm -f $@
	cp $< $@
	chmod a-w+x $@
	printf "       OK\n"

.rb.html:
	printf "%13s  %-30s" "[ROCCO]" "$@"
	rocco $< >/dev/null
	printf "       OK\n"

.c.o:
	printf "%13s  %-30s" "[CC]" "$@"
	$(CC) -c $(CFLAGS) $<
	printf "       OK\n"

rpg-sh-setup: config.sh munge.rb
rpg: config.sh munge.rb

rpg-solve: rpg-solve.o strnatcmp.o
	printf "%13s  %-30s" "[LINK]" "$@"
	$(CC) $(CFLAGS) $(LDFLAGS) rpg-solve.o strnatcmp.o -o $@
	printf "       OK\n"

rpg-solve-fast.o: rpg-solve.c strnatcmp.h
strnatcmp.o: strnatcmp.c strnatcmp.h

build: $(PROGRAMS)

auto:
	while true; do $(MAKE) ; sleep 1; done

man:
	$(MAKE) -C doc man

doc: $(DOCHTML)

test: build
	cd test && $(SHELL) test-rpg.sh

install:
	mkdir -p "$(bindir)" || true
	for f in $(USERPROGRAMS); do \
		echo "$(INSTALL_PROGRAM) $$f $(bindir)"; \
		$(INSTALL_PROGRAM) $$f "$(bindir)"; \
	done
	mkdir -p "$(libexecdir)" || true
	for f in $(PROGRAMPROGRAMS); do \
		echo "$(INSTALL_PROGRAM) $$f $(libexecdir)"; \
		$(INSTALL_PROGRAM) $$f "$(libexecdir)"; \
	done

uninstall:
	for f in $(USERPROGRAMS); do \
		test -e "$(bindir)/$$f" || continue; \
		echo "rm -f $(bindir)/$$f"; \
		rm "$(bindir)/$$f"; \
	done
	for f in $(PROGRAMPROGRAMS) $(DEADPROGRAMS); do \
		test -e "$(libexecdir)/$$f" || continue; \
		echo "rm -f $(libexecdir)/$$f"; \
		rm "$(libexecdir)/$$f"; \
	done

install-local:
	./configure --prefix=/usr/local
	sleep 1
	make
	make install
	./configure --development

clean:
	rm -vf $(PROGRAMS) $(DOCHTML) $(OBJECTS)
	$(MAKE) -C doc clean

tags:
	ctags --extra=+f  \
		--totals=yes  \
		--fields=+iaS \
		--exclude=@.gitignore \
		--exclude=/usr/X11    \
		-R -f tags . /usr/include

.SILENT:

.PHONY: install uninstall clean tags
