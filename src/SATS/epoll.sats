#include "./../HATS/includes.hats"

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

fn setnonblocking{n:int|n>=0}(fdes: int(n)): int
fn epoll_create(flags: int): epoll_fd = "mac#"
fn epoll_ctl(e: epoll_fd, p: epoll_flag, fd: int, ev: &epoll_event): intBtwe(~1, 0) = "mac#"
fn epoll_wait{n, i:nat | i <= n}(e: epoll_fd, evs: &array(epoll_event?, n) >> array(epoll_event, n), max: int(n), timeout: int): int(i) = "mac#"
fn signalfd(fd: int, set: &sigset_t, flags: int): [n:int|n >= ~1] int(n) = "mac#"
fn sigprocmask(fd: sigmaskhow_t, set: &sigset_t, flags: int): int = "mac#"

absvtype Epoll_vtype(a:vt@ype)
vtypedef Epoll(a:vt@ype) = Epoll_vtype(a)
absvtype Watcher_vtype(a:vt@ype,b:vt@ype)
vtypedef Watcher(a:vt@ype,b:vt@ype) = Watcher_vtype(a,b)
typedef callback(a:vt@ype,b:vt@ype) = (!Epoll(a), !Watcher(a,b), uint) -<fun1> void
vtypedef epoll_watcher(a:vt@ype,b:vt@ype) = [n:int | n >= 0] @{ fd=int(n), handler= callback(a,b), data=Option_vt(b), clear=(Option_vt(b))-<fun0,!wrt> void }
datavtype watcher_(a:vt@ype,b:vt@ype) = W of epoll_watcher(a,b)
vtypedef epoll_ctx(a:vt@ype) = @{ epoll=epoll_fd, running=bool, watchers=hashtbl(int, [b:vt@ype] watcher_(a,b)), data=Option_vt(a) }
datavtype epoll_(a:vt@ype) = E of epoll_ctx(a)
vtypedef Epoll = Epoll(void)
vtypedef Watcher(b:vt@ype) = Watcher(void,b)

fn make_epoll(): Epoll
fn{a:vt@ype} make_epoll1(data: a): Epoll(a)
fn free_epoll{a:vt@ype}(e: Epoll(a)): Option_vt(a)
fn run{a:vt@ype}(epoll: !Epoll(a)): void
fn stop_epoll{a:vt@ype}(epoll: !Epoll(a)): void

// for getting any data associated with the watcher
dataview epoll_v(a:vt@ype) = epoll_v
fn{a:vt@ype} epoll_data_takeout(e: !Epoll(a)): (epoll_v(a) | Option_vt(a))
fn{a:vt@ype} epoll_data_addback(pf: epoll_v(a) | e: !Epoll(a), data: a): void

// make a watcher that watches fd
fn make_watcher{n:int|n>=0;a,b:vt@ype}(fd: int(n), func: callback(a,b)): Watcher(a,b)
fn{b:vt@ype} make_watcher1{n:int|n>=0;a:vt@ype}(fd: int(n), func: callback(a,b), data: b, clear: (Option_vt(b)) -<fun0,!wrt> void): Watcher(a,b)

// register for an event
fn register_watcher{a,b:vt@ype}(e: !Epoll(a), w: Watcher(a,b), flags: uint): void
fn update_watcher{a,b:vt@ype}(e: !Epoll(a), w: !Watcher(a,b), flags: uint): void
fn unregister_watcher{n:int | n >= 0;a:vt@ype}(e: !Epoll(a), fd: int(n)): void
fn watcher_get_fd{a,b:vt@ype}(w: !Watcher(a,b)): [n:int | n >= 0] int(n)

// for getting any data associated with the watcher
dataview watcher_v(a:vt@ype) = watcher_v
fn{b:vt@ype} watcher_data_takeout{a:vt@ype}(w: !Watcher(a,b)): (watcher_v(b) | Option_vt(b))
fn{b:vt@ype} watcher_data_addback{a:vt@ype}(pf: watcher_v(b) | w: !Watcher(a,b), data: b): void