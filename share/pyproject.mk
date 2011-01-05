_self = $(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST))
PYPROJECT_SHARE_PATH ?= $(shell dirname $(_self))

# standard Python project Makefile
progname = $(shell awk '/^Source/ {print $$2}' debian/control)
name=

prefix = /usr/local
PATH_BIN = $(prefix)/bin

# WARNING: PATH_INSTALL is rm-rf'ed in uninstall
PATH_INSTALL = $(prefix)/lib/$(progname)
PATH_INSTALL_LIB = $(PATH_INSTALL)/pylib
PATH_INSTALL_LIBEXEC = $(PATH_INSTALL)/libexec
PATH_INSTALL_SHARE = $(prefix)/share/$(progname)
PATH_INSTALL_CONTRIB = $(PATH_INSTALL_SHARE)/contrib

PYTHON_LIB = $(shell echo /usr/lib/python* | sed 's/.* //')

PYCC_FLAGS = $(if $(INSTALL_NODOC),-OO,-O)
PYCC = python $(PYCC_FLAGS) $(PYTHON_LIB)/py_compile.py

PATH_DIST := $(progname)-$(shell date +%F)

# set explicitly to prevent INSTALL_SUID being set in the environment
INSTALL_SUID = 
INSTALL_FILE_MOD = $(if $(INSTALL_SUID), 4755, 755)

all: help

debug:
	$(foreach v, $V, $(warning $v = $($v)))
	@true

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

rename:
	$(if $(name),,($(error 'name' not set)))
	$(PYPROJECT_SHARE_PATH)/rename.sh $(progname) $(name)

updatelinks:
	@echo -n updating links... " "
	@$(PYPROJECT_SHARE_PATH)/updatelinks.sh
	@echo done.
	@echo

execproxy: TRUEPATH_INSTALL = $(shell echo $(PATH_INSTALL) | sed -e 's/debian\/$(progname)//g')
execproxy: execproxy.c
	gcc execproxy.c -DMODULE_PATH=\"$(TRUEPATH_INSTALL)/wrapper.pyo\" -o _$(progname)
	strip _$(progname)

### Extendable targets

# target: help
define help/body
	@echo '=== Configuration variables:'
	@echo 'INSTALL_SUID   # if not empty string, install program suid'
	@echo 'INSTALL_NODOC  # if not empty string, compile without docstrings'
	@echo

	@echo '=== Targets:'
	@echo 'install   [ prefix=path/to/usr ] # default: prefix=$(value prefix)'
	@echo 'uninstall [ prefix=path/to/usr ]'
	@echo
	@echo 'updatelinks                      # update toolkit wrapper links'
	@echo
	@echo 'rename name=<newname>'
	@echo 'clean'
	@echo
	@echo 'dist                             # create distribution tarball'
	@echo 'gitdist                          # create git distribution tarball'
endef

# target: build
build/deps ?= execproxy
define build/body
	$(PYCC) pylib/*.py *.py
endef

# target: install
install/deps ?= build
define install/body
	@echo
	@echo \*\* CONFIG: prefix = $(prefix) \*\*
	@echo 

	install -d $(PATH_BIN) $(PATH_INSTALL) $(PATH_INSTALL_LIB) $(PATH_INSTALL_LIBEXEC)

	# if contrib exists
	contrib=$(wildcard contrib/*); \
	if [ "$$contrib" ]; then \
		mkdir -p $(PATH_INSTALL_CONTRIB); \
		cp -a contrib/* $(PATH_INSTALL_CONTRIB); \
	fi

	install -m 644 pylib/*.pyo $(PATH_INSTALL_LIB)
	-install -m 755 libexec/* $(PATH_INSTALL_LIBEXEC)

	install -m 644 wrapper.pyo $(PATH_INSTALL)
	python -O wrapper.py --version > $(PATH_INSTALL)/version.txt

	for f in $(progname)*; do \
		if [ -x $$f ]; then \
			cp -P $$f $(PATH_BIN); \
		fi; \
	done
	rm -f $(PATH_BIN)/$(progname)
	install -m $(INSTALL_FILE_MOD) _$(progname) $(PATH_BIN)/$(progname)
endef

# target: uninstall
define uninstall/body
	rm -rf $(PATH_INSTALL)
	rm -rf $(PATH_INSTALL_SHARE)
	rm -f $(PATH_BIN)/$(progname)

	# delete links from PATH_BIN
	for f in $(progname)-*; do rm -f $(PATH_BIN)/$$f; done
endef

# target: clean
define clean/body
	rm -f pylib/*.pyc pylib/*.pyo *.pyc *.pyo _$(progname)
endef

# construct target rules
define extendable_target
$1: $$($1/deps) $$($1/deps/extra)
	$$($1/pre)
	$$($1/body)
	$$($1/post)
endef

EXTENDABLE_TARGETS = help build install uninstall clean
$(foreach target,$(EXTENDABLE_TARGETS),$(eval $(call extendable_target,$(target))))

.PHONY: gitdist dist updatelinks rename debug $(EXTENDABLE_TARGETS)
