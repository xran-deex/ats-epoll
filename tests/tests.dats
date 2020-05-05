#include "../ats-epoll.hats"
#include "ats-unit-testing/ats-unit-testing.hats"
staload "libats/libc/SATS/stdio.sats"

staload $EPOLL

fn test1(c: !Context): void = {
    fn cb(e: !Epoll, w: !Watcher, evs: uint): void = {
        val () = println! "hello world"
        val c1 = getchar0()
        val c2 = getchar0()
        val (pf | opt) = watcher_data_takeout<Context>(w)
        val-~Some_vt(c) = opt
        val () = assert_equals1<int>(c, 97, c1)
        val () = watcher_data_addback(pf | w, c)
        val () = stop_epoll(e)
    }
    val e = make_epoll()
    val _ = setnonblocking(0)
    val w = make_watcher2(0, cb, c)
    val () = register_watcher(e, w, EPOLLIN lor EPOLLET)
    val () = run(e)
    val () = free_epoll(e)
}

fn test2(c: !Context): void = {
    fn cb(e: !Epoll, w: !Watcher, evs: uint): void = {
        val () = println! "hello world"
        val c1 = getchar0()
        val c2 = getchar0()
        val (pf | opt) = watcher_data_takeout<strptr>(w)
        val-~Some_vt(s) = opt
        val s2 = copy("world")
        val s3 = strptr_append(s, s2)
        val () = println!(c1, s3)
        val () = free(s)
        val () = free(s2)
        val () = watcher_data_addback<strptr>(pf | w, s3)
        val () = if c1 = 'a' then stop_epoll(e)
    }
    vtypedef str = @{p=strptr}
    val e = make_epoll()
    val _ = setnonblocking(0)
    val str = @{p=copy("hello")}
    fn clean(s: str):<!wrt> void = {
        val () = free(s.p)
    }
    val w = make_watcher3<str>(0, cb, str, clean)
    val () = register_watcher(e, w, EPOLLIN lor EPOLLET)
    val () = run(e)
    val () = free_epoll(e)
    val () = assert_equals1<int>(c, 0, 0)
}

implement main0() = {
    val r = create_runner()
    val s = create_suite("ats-epoll tests")

    val () = add_test(s, "test1", test1)
    val () = add_test(s, "test2", test2)

    val () = add_suite(r, s)
    val () = run_tests(r)
    val () = free_runner(r)
}