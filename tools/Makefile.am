
toolsdir = $(pkgdatadir)/tools
tools_SCRIPTS = \
	checks-list.py \
	gis2spv.py

edit = $(SED) \
	-e 's|@pkgdatadir[@]|$(pkgdatadir)|g' \
	-e 's|@datadir[@]|$(datadir)|g' \
	-e 's|@exec_prefix[@]|$(exec_prefix)|g' \
	-e 's|@prefix[@]|$(prefix)|g'

$(tools_SCRIPTS): $(tools_SCRIPTS:=.in) Makefile
	$(edit) $(top_srcdir)/tools/$@.in > $(top_builddir)/tools/$@

CLEANFILES = $(tools_SCRIPTS)

EXTRA_DIST = $(tools_SCRIPTS:=.in)
