### Makefile for skbdo -- Stanford Knowledge Base Development Organizer

## use BuildKit (https://github.com/netj/buildkit)
PROJECTNAME = skbdo

# prepare build dependencies under .depends/
DEPENDSDIR = .depends

include buildkit/modules.mk
buildkit/modules.mk:
	git submodule update --init

