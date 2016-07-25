AC_PREREQ([2.67])
AC_INIT([spvd],[1.0.2],[contact@smartjog.com])

AM_INIT_AUTOMAKE([-Wall 1.11 foreign no-dist-gzip dist-xz])
AM_SILENT_RULES([yes])

AM_PATH_PYTHON([2.6])

AC_PROG_SED
SJ_PROG_SJCONF
AC_PATH_PROG(TXT2TAGS, txt2tags)

AC_SUBST([pluginspkgdatadir], [\$\(pkgdatadir\)/plugins])

AC_CONFIG_FILES([
	Makefile
	bin/Makefile
	doc/Makefile
	etc/Makefile
	share/Makefile
	share/plugins/Makefile
	sjconf/Makefile
	sjconf/confs/Makefile
	sjconf/plugins/spvd.py
	tools/Makefile
])

AC_OUTPUT
