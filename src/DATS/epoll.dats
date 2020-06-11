#include "./../HATS/includes.hats"
staload "./../SATS/epoll.sats"
staload "libats/libc/SATS/errno.sats"
#define ATS_DYNLOADFLAG 0
#define ATS_EXTERN_PREFIX "epoll_"

assume Epoll_vtype(a:vt@ype) = epoll_(a)
assume Watcher_vtype(a:vt@ype,b:vt@ype) = watcher_(a,b)

implement hash_key<int>(k) = g0int2uint k

implement setnonblocking(fd) = ret where {
    val (pf | fdes) = fildes_iget_int(fd)
    val r = fildes_isgtez(fdes)
    val ret = if r then ret where {
        val f = fcntl_getfl(fdes)
        val ret = fcntl_setfl(fdes, f lor O_NONBLOCK)
    } else ~1
    prval() = pf(fdes)
}

// implement epoll$clear<void>(p) = {
//     prval () = $UNSAFE.cast2void(p)
// }

fn watch_sig{a:vt@ype}(e: !Epoll(a)): void = {
    fn handle_signal(e: !Epoll(a), w: !Watcher(a,void), evs: uint): void = () where {
        val+@E(ep) = e
        val () = ep.running := false
        prval () = fold@(e)
    }
    var s: sigset_t?
    val i = sigemptyset(s)
    val () = if i = 0 then {
        prval() = opt_unsome(s)
        val i = sigaddset(s, SIGINT)
        val _ = sigprocmask(SIG_BLOCK, s, 0)
        val fd = signalfd(~1, s, 0)
        val () = if fd > 0 then {
            val _ = setnonblocking(fd)
            val w = make_watcher{..}(fd, handle_signal)
            val () = register_watcher(e, w, EPOLLIN)
        }
    } else {
        prval() = opt_unnone(s)
    }
}

fn{a:vt@ype} watch_sig1(e: !Epoll(a)): void = {
    fn handle_signal(e: !Epoll(a), w: !Watcher(a,void), evs: uint): void = () where {
        val+@E(ep) = e
        val () = ep.running := false
        prval () = fold@(e)
    }
    var s: sigset_t?
    val i = sigemptyset(s)
    val () = if i = 0 then {
        prval() = opt_unsome(s)
        val i = sigaddset(s, SIGINT)
        val _ = sigprocmask(SIG_BLOCK, s, 0)
        val fd = signalfd(~1, s, 0)
        val () = if fd > 0 then {
            val _ = setnonblocking(fd)
            val w = make_watcher{..}(fd, handle_signal)
            val () = register_watcher(e, w, EPOLLIN)
        }
    } else {
        prval() = opt_unnone(s)
    }
}

implement make_epoll() = res where {
    val ep = epoll_create(1)
    val res = E(@{ 
        epoll=ep, 
        running=false, 
        watchers=hashtbl_make_nil(i2sz 100), 
        data=None_vt()
    })
    val () = watch_sig(res)
}

implement{a} make_epoll1(data) = res where {
    val ep = epoll_create(1)
    val res = E(@{ 
        epoll=ep, 
        running=false, 
        watchers=hashtbl_make_nil(i2sz 100), 
        data=Some_vt(data)
    })
    val () = watch_sig1(res)
}

#define MAX 1024

implement run(e) = {
    val+@E(ep) = e

    val fd = ep.epoll
    val () = ep.running := true
    prval() = fold@(e)

    fun run_helper{a:vt@ype}(e: !Epoll(a), timeout: int): void = {
        val+@E(ep) = e

        var evs = @[epoll_event][MAX]()
        val n = epoll_wait{MAX,MAX}(ep.epoll, evs, MAX, timeout)
        val fd = ep.epoll
        val running = ep.running
        prval() = fold@(e)

        fun loop{n,i:nat | i < n && n >= 0}(evs: &(@[epoll_event][n]), n: int(n), i: int(i), e: !Epoll(a)): void = () where {
            val () = if i < n then {
                val watcher = $UNSAFE.castvwtp0{[b:vt@ype] Watcher(a,b)}(evs[i].data.ptr)
                val+@W(w) = watcher
                val fd = w.fd
                val handler = w.handler
                prval() = fold@(watcher)
                val () = if running then () where {
                    val () = handler(e, watcher, evs[i].events)
                } 
                prval() = $UNSAFE.cast2void(watcher)
                val () = if i+1 < n then loop(evs, n, i+1, e)
            }
        }
        val () = if n > 0 then loop(evs, n, 0, e)
        val () = if running then run_helper(e, 100)
    }
    val () = run_helper(e, 100)
}

fn{a:vt@ype} free_watcher{b:vt@ype}(w: Watcher(a,b)):<!wrt> void = {
    val+~W(watcher) = w
    val () = watcher.clear(watcher.data)
}

implement{a} epoll_data_takeout(e) = res where {
    val+@E(epoll) = e
    val res = (epoll_v | epoll.data)
    val () = epoll.data := None_vt()
    prval() = fold@(e)
}

implement{a} epoll_data_addback(pf | e, data) = {
    val+@E(epoll) = e
    val-~None_vt() = epoll.data
    val () = epoll.data := Some_vt(data) 
    prval() = fold@(e)
    extern prfun __ignore(p: epoll_v(a)): void
    prval() = __ignore(pf)
}

implement{b} watcher_data_takeout(w) = res where {
    val+@W(watcher) = w
    val res = (watcher_v | watcher.data)
    val () = watcher.data := None_vt()
    prval() = fold@(w)
}

implement{b} watcher_data_addback{a}(pf | w, data) = {
    val+@W(watcher) = w
    val-~None_vt() = watcher.data
    val () = watcher.data := Some_vt(data)
    prval() = fold@(w)
    extern prfun __ignore(p: watcher_v(b)): void
    prval() = __ignore(pf)
}

implement unregister_watcher(epoll, fd) = {
    val+@E(e) = epoll
    var d: epoll_data
    val () = d.ptr := the_null_ptr
    var ee: epoll_event
    val () = ee.data := d
    val () = ee.events := $UNSAFE.cast{uint}(0)
    val _ = epoll_ctl(e.epoll, EPOLL_CTL_DEL, fd, ee)
    prval () = fold@(epoll)
}

implement free_epoll{a}(ep) = res where {
    val+~E(e) = ep
    val () = hashtbl_foreach(e.watchers) where {
        implement hashtbl_foreach$fwork<int,[b:vt@ype]watcher_(a,b)><void>(k, v, env) = {
            val () = if k != 0 && k != 1 then {
                val _ = close0(k)
            }
            // var d: epoll_data
            // val () = d.ptr := $UNSAFE.castvwtp1{ptr}(0)
            // var ee: epoll_event
            // val () = ee.data := d
            // val () = ee.events := $UNSAFE.cast{uint}(0)
            // val _ = epoll_ctl(e.epoll, EPOLL_CTL_DEL, k, ee)
        }
    }
    val ls = hashtbl_listize(e.watchers)
    val () = list_vt_freelin(ls) where {
        implement(a) list_vt_freelin$clear<(int,[b:vt@ype]watcher_(a,b))>(w) = {
            val () = free_watcher<a>(w.1)
        }
    }
    val res = e.data
}

fn{b:vt@ype} clear(x: b):<!wrt> void = {
    prval () = $UNSAFE.cast2void(x)
}

implement make_watcher(fd, func) = 
    W(@{ fd = fd, handler=func, data=None_vt(), clear=clear })

implement{b} make_watcher1(fd, func, data, clear) = 
    W(@{ fd = fd, handler=func, data=Some_vt(data), clear=clear })

implement update_watcher(epoll, watch, flags) = {
    val+@W(w) = watch
    val+@E(e) = epoll

    val fd = w.fd
    prval () = fold@(watch)

    var data: epoll_data
    val () = data.ptr := $UNSAFE.castvwtp1{ptr}(watch)
    var ee: epoll_event
    val () = ee.data := data
    val () = ee.events := flags
    val ret = epoll_ctl(e.epoll, EPOLL_CTL_MOD, fd, ee)
    prval () = fold@(epoll)
}

implement register_watcher(epoll, watch, flags) = {
    val+@W(w) = watch
    val+@E(e) = epoll

    val fd = w.fd
    prval() = fold@(watch)

    var data: epoll_data

    val res = hashtbl_takeout_opt(e.watchers, fd)
    val () = case+ res of
             | ~Some_vt(w) => {
                val () = free_watcher(w)
                val () = data.ptr := $UNSAFE.castvwtp1{ptr}(watch)
                var ee: epoll_event
                val () = ee.data := data
                val () = ee.events := flags
                val ret = epoll_ctl(e.epoll, EPOLL_CTL_ADD, fd, ee)

                val () = if ret < 0 then println!("epoll_ctl err!: ", the_errno_get())
                val-~None_vt() = hashtbl_insert_opt(e.watchers, fd, watch)
             }
             | ~None_vt() => {
                val () = data.ptr := $UNSAFE.castvwtp1{ptr}(watch)
                var ee: epoll_event
                val () = ee.data := data
                val () = ee.events := flags
                val ret = epoll_ctl(e.epoll, EPOLL_CTL_ADD, fd, ee)
                val () = if ret < 0 then println!("epoll_ctl err: ", the_errno_get())
                val-~None_vt() = hashtbl_insert_opt(e.watchers, fd, watch)
             }
    prval() = fold@(epoll)
}

implement watcher_get_fd(w) = res where {
    val+@W(watcher) = w
    val res = watcher.fd
    prval() = fold@(w)
}

implement stop_epoll(e) = {
    val+@E(ep) = e
    val () = ep.running := false
    prval() = fold@(e)
}