
bin_SCRIPTS = \
	spvd

edit = sed \
	-e 's|@PACKAGE_VERSION[@]|$(PACKAGE_VERSION)|g' \
	-e 's|@localstatedir[@]|$(localstatedir)|g' \
	-e 's|@pkgdatadir[@]|$(pkgdatadir)|g' \
	-e 's|@datadir[@]|$(datadir)|g' \
	-e 's|@sysconfdir[@]|$(sysconfdir)|g' \
	-e 's|@exec_prefix[@]|$(exec_prefix)|g' \
	-e 's|@prefix[@]|$(prefix)|g'

$(bin_SCRIPTS): $(bin_SCRIPTS:=.in) Makefile
	$(edit) $@.in > $@

CLEANFILES = $(bin_SCRIPTS)

EXTRA_DIST = $(bin_SCRIPTS:=.in)
