### Makefile for MindBender -- Stanford Knowledge Base Development Environment

## use BuildKit (https://github.com/netj/buildkit)
PROJECTNAME = Mindbender
GITHUB_REPO = netj/mindbender
# preparing build dependencies under .depends/
DEPENDSDIR = .depends
# packaging as a executable binary
PACKAGENAME = mindbender
PACKAGEEXECUTES = bin/mindbender
PACKAGEVERSIONSUFFIX := -$(shell uname)-$(shell uname -m)

# keeping runtime dependencies
RUNTIMEDEPENDSDIR = depends

include buildkit/modules.mk
buildkit/modules.mk:
	git submodule update --init

