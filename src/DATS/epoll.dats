#include "./../HATS/includes.hats"
staload "./../SATS/epoll.sats"
staload "libats/libc/SATS/errno.sats"
#define ATS_DYNLOADFLAG 0
#define ATS_EXTERN_PREFIX "epoll_"

#staload $POOL

assume Epoll_vtype = epoll_
assume Watcher_vtype = watcher_

implement hash_key<int>(k) = g0int2uint k

implement{} setnonblocking(fd) = ret where {
    val (pf | fdes) = fildes_iget_int(fd)
    val r = fildes_isgtez(fdes)
    val ret = if r then ret where {
        val f = fcntl_getfl(fdes)
        val ret = fcntl_setfl(fdes, f lor O_NONBLOCK)
    } else ~1
    prval() = pf(fdes)
}

implement{} make_epoll() = res where {
    val ep = epoll_create(1)
    val res = E(@{ epoll=ep, running=false, watchers=hashtbl_make_nil(i2sz 100) })
    fun handle_signal(e: !Epoll, w: !Watcher, evs: uint): void = () where {
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
            val w = make_watcher(fd, handle_signal)
            val () = register_watcher(res, w, EPOLLIN)
        }
    } else {
        prval() = opt_unnone(s)
    }
}

#define MAX 1024

implement{} run(e) = {
    val+@E(ep) = e

    val fd = ep.epoll
    val () = ep.running := true
    prval() = fold@(e)

    fun run_helper(e: !Epoll, timeout: int): void = {
        val+@E(ep) = e

        var evs = @[epoll_event][MAX]()
        val n = epoll_wait{MAX,MAX}(ep.epoll, evs, MAX, timeout)
        val fd = ep.epoll
        val running = ep.running
        prval() = fold@(e)

        fun loop{n,i:nat | i < n && n >= 0}(evs: &(@[epoll_event][n]), n: int(n), i: int(i), e: !Epoll): void = () where {
            val () = if i < n then {
                val watcher = $UNSAFE.castvwtp0{Watcher}(evs[i].data.ptr)
                val+@W(w) = watcher
                val fd = w.fd
                val handler = w.handler
                prval() = fold@(watcher)
                val () = if running then () where {
                    // val () = println!("Events: ", evs[i].events, ", fd: ", fd)
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

// implement(a:t@ype) gclear_ref<a>(x) = ()

// implement{} free_epoll$clear(c) = () where {
//     // prval() = $UNSAFE.castview2void(c)
//     val () = gclear_ref<a>(c)
// }

fn{} free_watcher(w: Watcher):<!wrt> void = {
    val+~W(watcher) = w
    val () = watcher.cleanup(watcher.data)
    // val data = $UNSAFE.castvwtp0{Option_vt(a)}(watcher.data)
    // val () = (case+ data of
    // | ~None_vt() => ()
    // | @Some_vt(d) => let
    //      val () = free_epoll$clear<a>(d)
    //      val () = free@{a}(data)
    //     in
    //     ()
    //     end)
}

// extern castfn vtake{a:vt@ype}(x: Option_vt a):<> (watcher_v(a), (watcher_v(a), a) -<lin,prf> void | Option_vt a)

// fn{a:vt@ype} addback(pf: watcher_v(a) | w: !Watcher, data: a): void = {
//     val+@W(watcher) = w
//     val () = watcher.data := $UNSAFE.castvwtp0{ptr}(data)
//     prval() = fold@(w)
//     extern prfun __ignore{a:vt@ype}(p: watcher_v(a)): void
//     prval() = __ignore(pf)
// }

implement{a} watcher_data_takeout(w) = res where {
    val+@W(watcher) = w
    val null = watcher.data = the_null_ptr
    val data = $UNSAFE.castvwtp1{a}(watcher.data)
    val res = (if null then ret where {
        val ret = None_vt()
        prval () = $UNSAFE.cast2void(data)
    } else Some_vt(data)): Option_vt(a)
    val res = (watcher_v | res)
    val () = watcher.data := $UNSAFE.castvwtp0{ptr}(0)
    prval() = fold@(w)
}

implement{a} watcher_data_addback(pf | w, data) = {
    val+@W(watcher) = w
    val () = watcher.data := $UNSAFE.castvwtp0{ptr}(data)
    prval() = fold@(w)
    extern prfun __ignore{a:vt@ype}(p: watcher_v(a)): void
    prval() = __ignore(pf)
}

implement{} unregister_watcher(epoll, fd) = {
    val+@E(e) = epoll
    var d: epoll_data
    val () = d.ptr := $UNSAFE.castvwtp1{ptr}(0)
    var ee: epoll_event
    val () = ee.data := d
    val () = ee.events := $UNSAFE.cast{uint}(0)
    val _ = epoll_ctl(e.epoll, EPOLL_CTL_DEL, fd, ee)
    prval () = fold@(epoll)
}

implement{} free_epoll(ep: epoll_): void = {
    val+~E(e) = ep
    val () = hashtbl_foreach(e.watchers) where {
        implement hashtbl_foreach$fwork<int,watcher_><void>(k, v, env) = {
            // val () = println!("Closing fd: ", k)
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
        implement list_vt_freelin$clear<(int,watcher_)>(w) = {
            val () = free_watcher(w.1)
        }
    }
}

fn{} cleanup(p: ptr):<!wrt> void = {
    prval () = $UNSAFE.cast2void(p)
}

implement{} make_watcher(fd, func) = 
    W(@{ fd = fd, handler=func, data=the_null_ptr, cleanup=cleanup })

implement{a} make_watcher2(fd, func, data) = 
    W(@{ fd = fd, handler=func, data=$UNSAFE.castvwtp1{ptr}(data), cleanup=cleanup })

implement{a} make_watcher3(fd, func, data, cleanup) = 
    W(@{ fd = fd, handler=func, data=$UNSAFE.castvwtp0{ptr}(data), cleanup=$UNSAFE.castvwtp1{cleanup_func} cleanup })

implement{} update_watcher(epoll, watch, flags) = {
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

implement{} register_watcher(epoll, watch, flags) = {
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

implement{} watcher_get_fd(w) = res where {
    val+@W(watcher) = w
    val res = watcher.fd
    prval() = fold@(w)
}

implement{} stop_epoll(e) = {
    val+@E(ep) = e
    val () = ep.running := false
    prval() = fold@(e)
}