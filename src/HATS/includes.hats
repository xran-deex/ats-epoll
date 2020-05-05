#include "share/atspre_define.hats"
#include "share/atspre_staload.hats"
staload "libats/libc/SATS/time.sats"
staload "libats/libc/SATS/unistd.sats"
staload "libats/libc/SATS/fcntl.sats"
staload "libats/libc/SATS/stdio.sats"
staload "libats/libc/SATS/signal.sats"
staload "libats/SATS/linmap_list.sats"
staload _ = "libats/DATS/linmap_list.dats"
staload "libats/SATS/hashtbl_chain.sats"
staload _ = "libats/DATS/hashtbl_chain.dats"
staload _ = "libats/DATS/hashfun.dats"
#include "ats-threadpool/ats-threadpool.hats"
#include "shared_vt/ats-shared-vt.hats"
#include "ats-channel/ats-channel.hats"

%{
#include <sys/epoll.h>
#include <sys/signalfd.h>
%}