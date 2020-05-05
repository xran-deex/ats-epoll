#include "./../HATS/includes.hats"

staload $POOL

typedef fd = int
typedef epoll_fd = int
typedef epoll_flag = uint

vtypedef epoll_data = $extype_struct "epoll_data_t" of {
    ptr = ptr
}
vtypedef epoll_event = $extype_struct "struct epoll_event" of {
    data = epoll_data,
    events = uint
}

macdef EPOLL_CTL_ADD = $extval(epoll_flag, "EPOLL_CTL_ADD")
macdef EPOLL_CTL_MOD = $extval(epoll_flag, "EPOLL_CTL_MOD")
macdef EPOLL_CTL_DEL = $extval(epoll_flag, "EPOLL_CTL_DEL")
macdef EPOLLOUT = $extval(uint, "EPOLLOUT")
macdef EPOLLET = $extval(uint, "EPOLLET")
macdef EPOLLERR = $extval(uint, "EPOLLERR")
macdef EPOLLIN = $extval(uint, "EPOLLIN")
macdef EPOLLRDHUP = $extval(uint, "EPOLLRDHUP")
macdef EPOLLHUP = $extval(uint, "EPOLLHUP")
macdef EPOLLONESHOT = $extval(uint, "EPOLLONESHOT")
macdef EPOLLEXCLUSIVE = $extval(uint, "EPOLLEXCLUSIVE")
macdef O_NONBLOCK = $extval(fcntlflags, "O_NONBLOCK")
macdef SOMAXCONN = $extval(int, "SOMAXCONN")

fn{} setnonblocking{n:int|n>=0}(fdes: int(n)): int
fn epoll_create(flags: int): epoll_fd = "mac#"
fn epoll_ctl(e: epoll_fd, p: epoll_flag, fd: int, ev: &epoll_event): intBtwe(~1, 0) = "mac#"
fn epoll_wait{n, i:nat | i <= n}(e: epoll_fd, evs: &array(epoll_event?, n) >> array(epoll_event, n), max: int(n), timeout: int): int(i) = "mac#"
fn signalfd(fd: int, set: &sigset_t, flags: int): [n:int|n >= ~1] int(n) = "mac#"
fn sigprocmask(fd: sigmaskhow_t, set: &sigset_t, flags: int): int = "mac#"

absvtype Epoll_vtype
vtypedef Epoll = Epoll_vtype
absvtype Watcher_vtype
vtypedef Watcher = Watcher_vtype
typedef callback = (!Epoll, !Watcher, uint) -<fun1> void
typedef cleanup_func = (ptr) -<fun0,!wrt> void
vtypedef epoll_watcher = [n:int | n >= 0] @{ fd=int(n), handler= callback, data=ptr, cleanup=cleanup_func }
datavtype watcher_ = W of epoll_watcher
vtypedef epoll_ctx = @{ epoll=epoll_fd, running=bool, watchers=hashtbl(int, watcher_) }

datavtype epoll_ = E of epoll_ctx

fn{} make_epoll(): Epoll
fn{} free_epoll(d: Epoll): void
fn{} run(epoll: !Epoll): void
fn{} stop_epoll(epoll: !Epoll): void

// make a watcher that watches fd
fn{} make_watcher{n:int|n>=0}(fd: int(n), func: callback): Watcher
// make a watcher that watches fd with some data
fn{a:vt@ype} make_watcher2{n:int|n>=0}(fd: int(n), func: callback, data: !a): Watcher
// make a watcher that watches fd with some data and a cleanup function
fn{a:vt@ype} make_watcher3{n:int|n>=0}(fd: int(n), func: callback, data: a, cleanup: (a) -<fun0,!wrt> void): Watcher

// register for an event
fn{} register_watcher(e: !Epoll, w: Watcher, flags: uint): void
fn{} update_watcher(e: !Epoll, w: !Watcher, flags: uint): void
fn{} unregister_watcher{n:int | n >= 0}(e: !Epoll, fd: int(n)): void
fn{} watcher_get_fd(w: !Watcher): [n:int | n >= 0] int(n)

// for getting any data associated with the watcher
dataview watcher_v(a:vt@ype) = watcher_v
fn{a:vt@ype} watcher_data_takeout(w: !Watcher): (watcher_v(a) | Option_vt(a))
fn{a:vt@ype} watcher_data_addback(pf: watcher_v(a) | w: !Watcher, data: a): void