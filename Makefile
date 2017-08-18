#-------------------------------------------------------------------------
#
# Makefile for the pl/tcl procedural language
#
# src/pl/tcl/Makefile
#
#-------------------------------------------------------------------------

subdir = src/pl/tcl

#################################################
#
# CHANGES FOR STAND-ALONE REPOSITORY
#
# All the real changes are in stand-alone.mk, which we include. BUT, we need to
# ensure that the user has set top_builddir, so we must comment it here! This
# is the only modification to the original Makefile; please try to keep it that
# way!
#
# COMMENTED OUT: top_builddir = ../../..

# NOTE: This over-rides subdir! (set above)
include stand-alone.mk

#
#  END CHANGES
#
#################################################

include $(top_builddir)/src/Makefile.global


override CPPFLAGS := -I. -I$(srcdir) $(TCL_INCLUDE_SPEC) $(CPPFLAGS)

# On Windows, we don't link directly with the Tcl library; see below
ifneq ($(PORTNAME), win32)
SHLIB_LINK = $(TCL_LIB_SPEC) $(TCL_LIBS) -lc
endif

PGFILEDESC = "PL/Tcl - procedural language"

NAME = pltcl

OBJS = pltcl.o $(WIN32RES)

DATA = pltcl.control pltcl--1.0.sql pltcl--unpackaged--1.0.sql \
       pltclu.control pltclu--1.0.sql pltclu--unpackaged--1.0.sql

REGRESS_OPTS = --dbname=$(PL_TESTDB) --load-extension=pltcl
REGRESS = pltcl_setup pltcl_queries pltcl_unicode

# Tcl on win32 ships with import libraries only for Microsoft Visual C++,
# which are not compatible with mingw gcc. Therefore we need to build a
# new import library to link with.
ifeq ($(PORTNAME), win32)

tclwithver = $(subst -l,,$(filter -l%, $(TCL_LIB_SPEC)))
TCLDLL = $(dir $(TCLSH))/$(tclwithver).dll

OBJS += lib$(tclwithver).a

lib$(tclwithver).a: $(tclwithver).def
	dlltool --dllname $(tclwithver).dll --def $(tclwithver).def --output-lib lib$(tclwithver).a

$(tclwithver).def: $(TCLDLL)
	pexports $^ > $@

endif # win32


include $(top_srcdir)/src/Makefile.shlib


all: all-lib

# Force this dependency to be known even without dependency info built:
pltcl.o: pltclerrcodes.h

# generate pltclerrcodes.h from src/backend/utils/errcodes.txt
pltclerrcodes.h: $(top_srcdir)/src/backend/utils/errcodes.txt generate-pltclerrcodes.pl
	$(PERL) $(srcdir)/generate-pltclerrcodes.pl $< > $@

distprep: pltclerrcodes.h

install: all install-lib install-data

installdirs: installdirs-lib
	$(MKDIR_P) '$(DESTDIR)$(datadir)/extension'

uninstall: uninstall-lib uninstall-data

install-data: installdirs
	$(INSTALL_DATA) $(addprefix $(srcdir)/, $(DATA)) '$(DESTDIR)$(datadir)/extension/'

uninstall-data:
	rm -f $(addprefix '$(DESTDIR)$(datadir)/extension'/, $(notdir $(DATA)))

.PHONY: install-data uninstall-data


check: submake
	$(pg_regress_check) $(REGRESS_OPTS) $(REGRESS)

installcheck: submake
	$(pg_regress_installcheck) $(REGRESS_OPTS) $(REGRESS)

.PHONY: submake
submake:
	$(MAKE) -C $(top_builddir)/src/test/regress pg_regress$(X)

# pltclerrcodes.h is in the distribution tarball, so don't clean it here.
clean distclean: clean-lib
	rm -f $(OBJS)
	rm -rf $(pg_regress_clean_files)
ifeq ($(PORTNAME), win32)
	rm -f $(tclwithver).def
endif

maintainer-clean: distclean
	rm -f pltclerrcodes.h
