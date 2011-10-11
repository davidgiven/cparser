GOAL = $(BUILDDIR)/cparser

BUILDDIR ?= build
variant  ?= debug# Different libfirm variants (debug, optimize, profile)

FIRM_HOME   = libfirm
FIRM_CPPFLAGS = -I$(FIRM_HOME)/include
FIRM_LIBS   = -lm
LIBFIRM_FILE = build/$(variant)/libfirm.a
FIRM_VERSION = 1.19.1
FIRM_URL = http://downloads.sourceforge.net/project/libfirm/libfirm/$(FIRM_VERSION)/libfirm-$(FIRM_VERSION).tar.bz2?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Flibfirm%2Ffiles%2Flibfirm%2F&ts=1299786346&use_mirror=ignum

CPPFLAGS  = -I.
CPPFLAGS += $(FIRM_CPPFLAGS)

CFLAGS += -Wall -W -Wstrict-prototypes -Wmissing-prototypes -std=c99 -pedantic
CFLAGS_debug = -O0 -g
CFLAGS_optimize = -O3 -fomit-frame-pointer -DNDEBUG
CFLAGS_profile = -pg -O3 -fno-inline
CFLAGS += $(CFLAGS_$(variant))
ICC_CFLAGS = -O0 -g3 -std=c99 -Wall
#LFLAGS += -pg
ICC    ?= true
GCCO1  ?= true

LFLAGS += $(FIRM_LIBS)

SOURCES := \
	adt/hashset.c \
	adt/strset.c \
	adt/strutil.c \
	attribute.c \
	parser.c \
	ast.c \
	ast2firm.c \
	builtins.c \
	diagnostic.c \
	driver/firm_machine.c \
	driver/firm_opt.c \
	driver/firm_timing.c \
	entity.c \
	entitymap.c \
	format_check.c \
	input.c \
	lexer.c \
	main.c \
	mangle.c \
	preprocessor.c \
	printer.c \
	symbol_table.c \
	token.c \
	type.c \
	type_hash.c \
	types.c \
	help.c \
	warning.c \
	walk.c \
	wrappergen/write_fluffy.c \
	wrappergen/write_jna.c

OBJECTS = $(SOURCES:%.c=build/%.o)
DEPENDS = $(OBJECTS:%.o=%.d)

SPLINTS = $(addsuffix .splint, $(SOURCES))
CPARSERS = $(addsuffix .cparser, $(SOURCES))
CPARSEROS = $(SOURCES:%.c=build/cpb/%.o)
CPARSEROS_E = $(SOURCES:%.c=build/cpbe/%.o)
CPARSEROS2 = $(SOURCES:%.c=build/cpb2/%.o)

Q = @

all: $(GOAL)

.PHONY: all bootstrap bootstrap2 bootstrape clean selfcheck splint $(FIRM_HOME)/$(LIBFIRM_FILE)

-include $(DEPENDS)

config.h:
	cp config.h.in $@

%.h:
	@true

REVISION ?= $(shell git describe --abbrev=40 --always --dirty --match '')

# Update revision.h if necessary
UNUSED := $(shell \
	REV="\#define cparser_REVISION \"$(REVISION)\""; \
	echo "$$REV" | cmp -s - revision.h 2> /dev/null || echo "$$REV" > revision.h \
)

DIRS   := $(sort $(dir $(OBJECTS)))
UNUSED := $(shell mkdir -p $(DIRS) $(DIRS:$(BUILDDIR)/%=$(BUILDDIR)/cpb/%) $(DIRS:$(BUILDDIR)/%=$(BUILDDIR)/cpb2/%) $(DIRS:$(BUILDDIR)/%=$(BUILDDIR)/cpbe/%))

$(FIRM_HOME)/$(LIBFIRM_FILE):
ifeq "$(wildcard $(FIRM_HOME) )" ""
	@echo 'Download and extract libfirm tarball ...'
	$(Q)curl -s -L "${FIRM_URL}" -o "libfirm-$(FIRM_VERSION).tar.bz2"
	$(Q)tar xf "libfirm-$(FIRM_VERSION).tar.bz2"
	$(Q)mv "libfirm-$(FIRM_VERSION)" $(FIRM_HOME)
endif
	$(Q)$(MAKE) -C $(FIRM_HOME) $(LIBFIRM_FILE)

$(GOAL): $(FIRM_HOME)/$(LIBFIRM_FILE) $(OBJECTS)
	@echo "===> LD $@"
	$(Q)$(CC) $(OBJECTS) $(LFLAGS) $(FIRM_HOME)/$(LIBFIRM_FILE) -o $(GOAL)

splint: $(SPLINTS)

selfcheck: $(CPARSERS)

bootstrap: build/cpb build/cpb/adt build/cpb/driver $(CPARSEROS) cparser.bootstrap

bootstrape: build/cpb build/cpb/adt build/cpb/driver $(CPARSEROS_E) cparser.bootstrape

bootstrap2: build/cpb2 build/cpb2/adt build/cpb2/driver $(CPARSEROS2) cparser.bootstrap2

%.c.splint: %.c
	@echo '===> SPLINT $<'
	$(Q)splint $(CPPFLAGS) $<

%.c.cparser: %.c
	@echo '===> CPARSER $<'
	$(Q)./cparser $(CPPFLAGS) -fsyntax-only $<

build/cpb/%.o: %.c build/cparser
	@echo '===> CPARSER $<'
	$(Q)./build/cparser $(CPPFLAGS) -std=c99 -Wall -g3 -c $< -o $@

build/cpbe/%.o: %.c
	@echo '===> ECCP $<'
	$(Q)eccp $(CPPFLAGS) -std=c99 -Wall -c $< -o $@

build/cpb2/%.o: %.c cparser.bootstrap
	@echo '===> CPARSER.BOOTSTRAP $<'
	$(Q)./cparser.bootstrap $(CPPFLAGS) -Wall -g -c $< -o $@

cparser.bootstrap: $(CPARSEROS)
	@echo "===> LD $@"
	$(Q)./build/cparser $(CPARSEROS) $(LFLAGS) -o $@

cparser.bootstrape: $(CPARSEROS_E)
	@echo "===> LD $@"
	$(Q)gcc $(CPARSEROS_E) $(LFLAGS) -o $@

cparser.bootstrap2: $(CPARSEROS2)
	@echo "===> LD $@"
	$(Q)./cparser.bootstrap $(CPARSEROS2) $(LFLAGS) -o $@

build/%.o: %.c
	@echo '===> CC $<'
	$(Q)$(CC) $(CPPFLAGS) $(CFLAGS) -MMD -c $< -o $@

clean:
	@echo '===> CLEAN'
	$(Q)rm -rf build/* $(GOAL)
