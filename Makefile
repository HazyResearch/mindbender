### Makefile for skbdo -- Stanford Knowledge Base Development Organizer

## use BuildKit (https://github.com/netj/buildkit)
PROJECTNAME = skbdo
# preparing build dependencies under .depends/
DEPENDSDIR = .depends
# packaging as a executable binary
PACKAGEEXECUTES = bin/skbdo

# keeping runtime dependencies
RUNTIMEDEPENDSDIR = depends

include buildkit/modules.mk
buildkit/modules.mk:
	git submodule update --init

