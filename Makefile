ATSCC=$(PATSHOME)/bin/patscc
ATSOPT=$(PATSHOME)/bin/patsopt

ATSFLAGS=-IATS node_modules -IATS ../node_modules

CFLAGS=-DATS_MEMALLOC_LIBC -D_DEFAULT_SOURCE -I $(PATSHOME)/ccomp/runtime -I $(PATSHOME) -O3
LIBS=-latslib

APP     = libats-epoll.a
ifndef STATICLIB
	CFLAGS+=-fpic
	LIBS+=-shared
	APP     = libats-epoll.so
endif

EXEDIR  = target
ifdef OUTDIR
	EXEDIR = $(OUTDIR)
endif
SRCDIR  = src
OBJDIR  = .build
vpath %.dats src
vpath %.dats src/DATS
vpath %.sats src/SATS
dir_guard=@mkdir -p $(@D)
SRCS    := $(shell find $(SRCDIR) -name '*.dats' -type f -exec basename {} \;)
OBJS    := $(patsubst %.dats,$(OBJDIR)/%.o,$(SRCS))

.PHONY: clean setup

all: $(EXEDIR)/$(APP)

$(EXEDIR)/$(APP): $(OBJS)
	$(dir_guard)
ifdef STATICLIB
	ar rcs $@ $(OBJS)
endif
ifndef STATICLIB
	$(CC) $(CFLAGS) -o $(EXEDIR)/$(APP) $(OBJS) $(LIBS)
endif

.SECONDEXPANSION:
$(OBJDIR)/%.o: %.c
	$(dir_guard)
	$(CC) $(CFLAGS) -c $< -o $(OBJDIR)/$(@F)

$(OBJDIR)/%.c: %.dats
	$(dir_guard)
	$(ATSOPT) $(ATSFLAGS) -o $(OBJDIR)/$(@F) -d $<

RMF=rm -f

clean: 
	$(RMF) $(EXEDIR)/$(APP)
	$(RMF) $(OBJS)
	+make -C tests clean

test: all
	+make -C tests
	+make -C tests run