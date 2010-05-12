AC_PREREQ(2.61)

AC_INIT([spvd],[0.8.0])

AM_INIT_AUTOMAKE([foreign])

AM_PATH_PYTHON

AC_PROG_SED
AC_PATH_PROG(TXT2TAGS, txt2tags)

AC_SUBST([pluginspkgdatadir], [\$\(pkgdatadir\)/plugins])

AC_CONFIG_FILES([
	Makefile
	bin/Makefile
	data/Makefile
	doc/Makefile
	etc/Makefile
	share/Makefile
	share/plugins/Makefile
	tools/Makefile
])

AC_OUTPUT
