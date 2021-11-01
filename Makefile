.POSIX:
.SUFFIXES: .el .elc

EMACS    = emacs
MAKEINFO = makeinfo
COMPILE  = lin.elc

all: compile lin.info

.PHONY: compile
compile: $(COMPILE)

.PHONY: clean
clean:
	rm -f $(COMPILE) lin.texi lin.info

lin.texi: README.org
	$(EMACS) -Q --batch $< -f org-texinfo-export-to-texinfo --kill

lin.info: lin.texi
	$(MAKEINFO) $<

.el.elc:
	$(EMACS) -Q --batch -L . -f batch-byte-compile $^
