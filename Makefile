### Makefile for MindBender -- Stanford Knowledge Base Development Environment

## use BuildKit (https://github.com/netj/buildkit)
PROJECTNAME = Mindbender
GITHUB_REPO = HazyResearch/mindbender
# preparing build dependencies under .depends/
DEPENDSDIR = .depends
# packaging as a executable binary
PACKAGENAME = mindbender
PACKAGEEXECUTES = bin/mindbender
PACKAGEVERSIONSUFFIX := -$(shell uname)-$(shell uname -m)

# list of modules
MODULES += compiler
MODULES += dashboard
MODULES += depends
MODULES += depends/nodejs
MODULES += gui/backend
MODULES += gui/frontend
MODULES += shell

# keeping runtime dependencies
RUNTIMEDEPENDSDIR = depends

include buildkit/modules.mk
buildkit/modules.mk:
	git submodule update --init


# add symlink to gui/frontend/src when under development (with work-in-progress)
ifneq ($(PACKAGEVERSION=%+WIP:%),$(PACKAGEVERSION))
polish: $(STAGEDIR)/gui/files/src
$(STAGEDIR)/gui/files/src:
	relsymlink gui/frontend/src $(STAGEDIR)/gui/files/
endif
