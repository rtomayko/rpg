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

SOURCES = \
	rpg-sh-setup.sh rpg.sh rpg-config.sh rpg-fetch.sh rpg-install.sh \
	rpg-uninstall.sh rpg-build.sh rpg-env.sh rpg-sync.sh \
	rpg-resolve.sh rpg-upgrade.sh rpg-steal.sh rpg-fsck.sh rpg-outdated.sh \
	rpg-package-register.sh rpg-package-install.sh rpg-unpack.sh \
	rpg-package-spec.rb rpg-parse-index.rb rpg-shit-list.sh rpg-prepare.sh \
	rpg-help.sh rpg-package-index.sh rpg-list.sh rpg-dependencies.sh \
	rpg-leaves.sh rpg-solve.c

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
	rpg-leaves rpg-solve

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

.SILENT:

.PHONY: install uninstall clean
