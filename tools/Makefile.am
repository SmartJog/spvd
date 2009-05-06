
toolsdir = $(pkgdatadir)/tools
tools_DATA = \
	checks-list.py \
	gis2spv.py \
	spv-inject.sh

edit = sed \
	-e 's|@pkgdatadir[@]|$(pkgdatadir)|g' \
	-e 's|@datadir[@]|$(datadir)|g' \
	-e 's|@exec_prefix[@]|$(exec_prefix)|g' \
	-e 's|@prefix[@]|$(prefix)|g'

$(tools_DATA): $(tools_DATA:=.in) Makefile
	$(edit) $(top_srcdir)/tools/$@.in > $(top_builddir)/tools/$@

CLEANFILES = $(tools_DATA)

EXTRA_DIST = $(tools_DATA:=.in)
