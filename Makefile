### Makefile for MindBender -- Stanford Knowledge Base Development Environment

## use BuildKit (https://github.com/netj/buildkit)
PROJECTNAME = mindbender
# preparing build dependencies under .depends/
DEPENDSDIR = .depends
# packaging as a executable binary
PACKAGEEXECUTES = bin/mindbender

# keeping runtime dependencies
RUNTIMEDEPENDSDIR = depends

include buildkit/modules.mk
buildkit/modules.mk:
	git submodule update --init

