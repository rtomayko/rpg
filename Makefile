# Default make target
all::

NAME = pgem
TARNAME = $(NAME)
SHELL = /bin/sh

srcdir      = .
prefix      = /usr/local
exec_prefix = ${prefix}
bindir      = ${exec_prefix}/bin
libexecdir  = ${exec_prefix}/libexec
datarootdir = ${prefix}/share
datadir     = ${datarootdir}
mandir      = ${datarootdir}/man
docdir      = $(datadir)/doc/$(TARNAME)

# Change this to `install-multi' if you want separate pgem-XXX commands. By
# default, all pgem- programs are combined into a single command.
INSTALLMETHOD = install-standalone

# ---- END OF CONFIGURATION ----

all:: build

SOURCES = pgem-sh-setup \
		  pgem \
		  pgem-config \
		  pgem-deps \
		  pgem-fetch \
		  pgem-install \
		  pgem-list \
		  pgem-version-test \
		  pgem-uninstall \
		  pgem-build \
		  pgem-env \
		  pgem-update \
		  pgem-resolve

STANDALONE = $(NAME)-sa

CLEAN = $(STANDALONE) syntax

build: syntax $(STANDALONE)
	@echo "  DONE  $(NAME) built successfully. Ready to \`make install'."

syntax: $(SOURCES)
	@for f in $(SOURCES); do \
		$(SHELL) -n $$f && \
		printf "SYNTAX  %-30s OK\n" "$$f"  || \
		printf "SYNTAX  %-30s BAD\n" "$$f"; \
	done
	@touch syntax

pgem-sa:
	@echo " BUILD  $(STANDALONE)"
	@$(SHELL) shc -m pgem $(SOURCES) > $(STANDALONE) || { \
		rm -f $(STANDALONE); \
		false; \
	}; \
	chmod 0755 $(STANDALONE)

install: $(INSTALLMETHOD)

install-standalone:
	mkdir -p $(bindir)
	cp pgem-sa $(bindir)/pgem
	chmod 0755 $(bindir)/pgem

install-multi:
	@mkdir -p $(bindir)
	@for f in $(SOURCES); do \
		echo "installing: $$f"; \
		cp $f "$(bindir)/$$f" && \
		chmod 0755 "$(bindir)/$$f"; \
	done

uninstall:
	@for f in $(SOURCES); do \
		test -e "$(bindir)/$$f" && continue; \
		echo "uninstalling: $$f"; \
		rm -f "$(bindir)/$$f"; \
	done

clean:
	rm -f $(CLEAN)

.PHONY: clean install install-standalone install-multi

FORCE:
