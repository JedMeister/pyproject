# standard Python project Makefile
progname=pyproject
name=

prefix=/usr/local
PATH_BIN=$(prefix)/bin

# WARNING: PATH_INSTALL is rm-rf'ed in uninstall
PATH_INSTALL=$(prefix)/lib/$(progname)
PATH_INSTALL_LIB=$(PATH_INSTALL)/pylib
PATH_INSTALL_LIBEXEC=$(PATH_INSTALL)/libexec

PYCC=python -O /usr/lib/python/py_compile.py
PYCC_NODOC=python -OO /usr/lib/python/py_compile.py

PATH_DIST := $(progname)-$(shell date +%F)

all:
	@echo "=== USAGE ==="
	@echo 
	@echo "make install-nodoc prefix=<dirpath>   # strip docstrings and install"
	@echo "make install prefix=<dirpath>"
	@echo "         (default prefix $(prefix))"
	@echo "make uninstall prefix=<dirpatch>"
	@echo
	@echo "make clean"
	@echo "make dist                      # create distribution tarball"
	@echo "make gitdist                   # create git distribution tarball"
	@echo
	@echo "make init name=<project-name>  # initialize project"
	@echo "make updatelinks               # update toolkit command links"
	@echo 

rename:
ifeq ($(progname),pyproject)
	@echo error: you need to make init first
else
ifeq ($(name),)
	@echo error: name not set
else
	scripts/rename.sh $(name)
endif
endif

init: clean
ifneq ($(progname),pyproject)
	@echo error: already initialized
else

ifeq ($(name),)
	@echo error: name not set
else
	scripts/rename.sh $(name)

	rm README
	rm -rf .git/
	cg-init -m "Initialized project $(name) from pyproject template"
endif

endif

updatelinks:
	@echo -n updating links... " "
	@scripts/updatelinks.sh
	@echo done.
	@echo

pycompile:
	$(PYCC) pylib/*.py *.py

pycompile-nodoc:
	$(PYCC_NODOC) pylib/*.py *.py

execproxy: execproxy.c
	gcc execproxy.c -DMODULE_PATH=\"$(PATH_INSTALL)/wrapper.pyo\" -o _$(progname)
	strip _$(progname)

uninstall:
	rm -rf $(PATH_INSTALL)
	rm -f $(PATH_BIN)/$(progname)

	# delete links from PATH_BIN
	for f in $(progname)-*; do rm -f $(PATH_BIN)/$$f; done

_install: execproxy
	@echo
	@echo \*\* CONFIG: prefix = $(prefix) \*\*
	@echo 

	install -d $(PATH_BIN) $(PATH_INSTALL) $(PATH_INSTALL_LIB) $(PATH_INSTALL_LIBEXEC)

	install -m 644 pylib/*.pyo $(PATH_INSTALL_LIB)
	-install -m 755 libexec/* $(PATH_INSTALL_LIBEXEC)

	install -m 644 version.pyo wrapper.pyo $(PATH_INSTALL)

	install -m 755 _$(progname) $(PATH_BIN)/$(progname)
	cp -P $(progname)-* $(PATH_BIN)	

install-nodoc: pycompile-nodoc _install

install: pycompile  _install

clean:
	rm -f pylib/*.pyc pylib/*.pyo *.pyc *.pyo _$(progname)
	rm -rf build/

dist: clean
	-mkdir -p $(PATH_DIST)

	-cp -a .git .gitignore $(PATH_DIST)
	-cp -a *.sh *.c *.py Makefile pylib/ libexec* $(PATH_DIST)

	tar jcvf $(PATH_DIST).tar.bz2 $(PATH_DIST)
	rm -rf $(PATH_DIST)


gitdist: clean
	-mkdir -p $(PATH_DIST)-git
	-cp -a .git $(PATH_DIST)-git
	cd $(PATH_DIST)-git && git-repack -a -d

	tar jcvf $(PATH_DIST)-git.tar.bz2 $(PATH_DIST)-git
	rm -rf $(PATH_DIST)-git
