#include "ats-epoll.hats"
#include "ats-unit-testing.hats"
staload "libats/libc/SATS/stdio.sats"

staload $EPOLL
staload $UT

fn test1(c: &Context): void = {
    fn cb(e: !Epoll(Context), w: !Watcher(Context,void), evs: uint): void = {
        val () = println! "hello world"
        val c1 = getchar0()
        val c2 = getchar0()
        val (pf | opt) = epoll_data_takeout<Context>(e)
        val-@Some_vt(c) = opt
        val () = assert_equals1<int>(c, 97, c1)
        prval () = fold@opt
        val () = epoll_data_addback(pf | e, opt)
        val () = stop_epoll(e)
    }
    val e = make_epoll1<Context>(c)
    val _ = setnonblocking(0)
    val w = make_watcher(0, cb)
    val () = register_watcher(e, w, EPOLLIN lor EPOLLET)
    val () = run(e)
    val-~Some_vt(c1) = free_epoll(e)
    val () = c := c1
}

fn test2(c: &Context): void = {
    vtypedef str = @{p=strptr}
    fn cb(e: !Epoll, w: !Watcher(str), evs: uint): void = {
        val () = println! "hello world"
        val c1 = getchar0()
        val c2 = getchar0()
        val (pf | opt) = watcher_data_takeout<str>(w)
        val-@Some_vt(s) = opt
        val s2 = copy("world")
        val s3 = strptr_append(s.p, s2)
        val () = println!(c1, s3)
        val () = free(s.p)
        val () = free(s2)
        val () = s.p := s3
        prval () = fold@opt
        // val-~Some_vt(s) = opt
        val () = watcher_data_addback<str>(pf | w, opt)
        val () = if c1 = 'a' then stop_epoll(e)
    }
    val e = make_epoll()
    val _ = setnonblocking(0)
    val str = @{p=copy("hello")}
    fn clear(s: Option_vt str):<!wrt> void = {
        val () = case+ s of
        | ~Some_vt p => free(p.p)
        | ~None_vt() => ()
    }
    val w = make_watcher1<str>(0, cb, str, clear)
    val () = register_watcher(e, w, EPOLLIN lor EPOLLET)
    val () = run(e)
    val-~None_vt() = free_epoll(e)
    val () = assert_equals1<int>(c, 0, 0)
}

fn test3(c: &Context): void = {
    vtypedef str = @{p=strptr}
    fn cb(e: !Epoll(str), w: !Watcher(str,void), evs: uint): void = {
        val () = println! "hello world"
        val c1 = getchar0()
        val c2 = getchar0()
        val (pf | opt) = epoll_data_takeout<str>(e)
        val-@Some_vt(s) = opt
        val s2 = copy("world")
        val s3 = strptr_append(s.p, s2)
        val () = println!(c1, s3)
        val () = free(s.p)
        val () = free(s2)
        val () = s.p := s3
        prval () = fold@opt
        // val-Some_vt(s) = opt
        val () = epoll_data_addback<str>(pf | e, opt)
        val () = if c1 = 'a' then stop_epoll(e)
    }
    val str = @{p=copy("hello")}
    val e = make_epoll1<str>(str)
    val _ = setnonblocking(0)
    val w = make_watcher(0, cb)
    val () = register_watcher(e, w, EPOLLIN lor EPOLLET)
    val () = run(e)
    val (pf | opt) = epoll_data_takeout<str>(e)
    val-@Some_vt(s) = opt
    val () = println!("Final: ", s.p)
    prval () = fold@opt
    val () = epoll_data_addback<str>(pf | e, opt)
    val-~Some_vt(s) = free_epoll(e)
    val () = free(s.p)
    val () = assert_equals1<int>(c, 0, 0)
}

implement main0() = {
    val r = create_runner()
    val s = create_suite("ats-epoll tests")

    val () = add_test(s, "test1", test1)
    val () = add_test(s, "test2", test2)
    val () = add_test(s, "test3 - global data", test3)

    val () = add_suite(r, s)
    val () = run_tests(r)
    val () = free_runner(r)
}
