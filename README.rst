=====
 spvd
=====

spvd is a generic supervision / monitoring daemon written in Python.

It is used internally at SmartJog to monitor several mission-critical
services.

spvd by itself does not perform any monitoring task, but instead acts
as a framework to run specific supervision jobs, which are implemented
as plugins. Sample plugins can be found in share/plugins.

While it is designed to work with webengine-spv to
fetch/update/reschedule/delete its checks, it is possible to create
plugins using other methods.


License
=======

spvd is released under the `GNU LGPL 2.1 <http://www.gnu.org/licenses/lgpl-2.1.html>`_.


Build and installation
=======================

Bootstrapping
-------------

spvd uses autotools for its build system.

If you checked out code from the git repository, you will need
autoconf and automake to generate the configure script and Makefiles.

To generate them, simply run::

    $ autoreconf -fvi

Building
--------

Webengine-spv builds like a typical autotools-based project::

    $ ./configure && make && make install


Development
===========

We use `semantic versioning <http://semver.org/>`_ for
versioning. When working on a development release, we append ``~dev``
to the current version to distinguish released versions from
development ones. This has the advantage of working well with Debian's
version scheme, where ``~`` is considered smaller than everything (so
version 1.10.0 is more up to date than 1.10.0~dev).


Authors
=======

spvd was started at SmartJog by Gilles Dartiguelongue in 2009. Various
employees and interns from SmartJog fixed bugs and added features
since then.

* Alexandre Bossard
* Clément Bœsch
* Dupuy Mathieu
* Gilles Dartiguelongue
* Guillaume Camera
* Mathieu Dupuy
* Maxime Mouial
* Nicolas Noirbent
* Philippe Bridant
* Rémi Cardona
* Thomas Souvignet
* Victor Goya
