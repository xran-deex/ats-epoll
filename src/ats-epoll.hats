#include "./HATS/includes.hats"
staload _ = "./DATS/epoll.dats"
staload EPOLL = "./SATS/epoll.sats"
staload _ = "libats/DATS/linmap_list.dats"
staload _ = "libats/DATS/hashtbl_chain.dats"
staload _ = "libats/DATS/hashfun.dats"
%{
#include <sys/epoll.h>
#include <sys/signalfd.h>
%}
