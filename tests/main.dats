#include "../ats-epoll.hats"
staload "libats/libc/SATS/sys/socket.sats"
staload "libats/libc/SATS/errno.sats"
staload _ = "libats/libc/DATS/sys/socket.dats"
staload "libats/libc/SATS/time.sats"
//
staload "libats/libc/SATS/unistd.sats"
staload "libats/libc/SATS/sys/socket.sats"
staload "libats/libc/SATS/sys/socket_in.sats"
//
staload "libats/libc/SATS/arpa/inet.sats"
staload "libats/libc/SATS/netinet/in.sats"

#include "ats-pthread-extensions/ats-pthread-ext.hats"

staload $EPOLL

%{#
#include "./main.cats"
%}

extern fn string_from_bytes{n,m:int | m < n && m > 0}(b: @[byte][n], cnt: int(m)): strnptr(m) = "mac#"
extern fn string_to_bytes{n,m:int | m > n}(b: string(n), buf: @[byte][m], size_t(n)): void = "mac#"
extern fn string_to_bytes2{n:int}(b: string(n)): bytes(n) = "mac#"
extern fn write_err2{n:int}(fd: int, s: string(n), size_t(n)): int = "mac#"
extern fn read_err2{n:int}(fd: int, s: bytes(n), size_t(n)): [m:int | m <= n] int(m) = "mac#"
extern fn reuseport(fd: int): void = "mac#"

fn get_server(): [n:int|n>= ~1] int(n) = res where {
    val inport = in_port_nbo(8888)
    val inaddr = in_addr_hbo2nbo (INADDR_ANY)
    //
    var servaddr: sockaddr_in_struct
    val () = sockaddr_in_init(servaddr, AF_INET, inaddr, inport)
    val (pf | sfd) = socket_AF_type_exn(AF_INET, SOCK_STREAM)
    val () = reuseport(sfd)
    val () = $extfcall(void, "atslib_libats_libc_bind_exn", sfd, addr@servaddr, socklen_in) 
    prval() = __assert(pf) where {
        extern praxi __assert{fd:int}(pf: socket_v(fd,init)): void
    }
    val res = sfd
}

fn listen{n:int|n>=0}(sfd: int(n)): void = {
    val _ = setnonblocking(sfd)
    val () = $extfcall(void, "atslib_libats_libc_listen_exn", sfd, SOMAXCONN) 
}

#define BUFSZ 1024

fun do_read(e: !Epoll, w: !Watcher, evs: uint): void = () where {
    val fd = watcher_get_fd(w)
    // val () = println!("Processing... ", fd)
    val isedge = (evs land EPOLLET) > 0
    val isread = (evs land EPOLLIN) > 0
    val iswrite = (evs land EPOLLOUT) > 0
    val iserr = (evs land EPOLLERR) > 0
    val isclose = (evs land (EPOLLRDHUP lor EPOLLHUP)) > 0
    // val () = println!("read: ", isread, ", write: ", iswrite, ", close: ", isclose, ", edge: ", isedge, ", error: ", iserr)
    // val () = if iserr then println!("err")
    // val () = if isclose then println!("close")
    val r = true
    val () = if r then if isread && ~iserr then {
        fun loop(e: !Epoll, w: !Watcher): void = {
            // val () = println!("fd: ", fd)
            var buf = @[byte][BUFSZ](int2byte0 0)
            val r = read_err2(fd, buf, i2sz (BUFSZ))
            val () = assertloc(BUFSZ > r)
            val () = if r <= 0 then {
                // val () = unregister_watcher(e, fd)
                // val _ = close0_exn(fd)
                val () = update_watcher(e, w, EPOLLOUT lor EPOLLET)
            } else if r > 0 then {
                // val str = string_from_bytes(buf, r)
                // val () = println!(str)
                // val () = free(str)
                val () = loop(e, w)
            }
        }
        val () = loop(e, w)
    }

    val () = if r && ~iserr then if iswrite then { 
        fun loop(e: !Epoll, w: !Watcher): void = {
            var buf = @[byte][1024](int2byte0 0)
            val hw = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 11\r\n\r\nHello World"
            // val () = string_to_bytes(hw, buf, string_length(hw))
            val len = string_length(hw)
            // val () = println!("writing: ", fd)
            val ret = write_err2(fd, hw, len)
            // val () = println!("ret: ", ret, "errno: ", the_errno_get())
            val () = if ret > 0 && the_errno_get() = 0 then loop(e, w) else {
                val () = update_watcher(e, w, EPOLLIN lor EPOLLET)
            }
        }
        val () = loop(e, w)
        // val _ = if isclose then {
        //     val () = remove_watcher(e, fd)
        //     // val () = println!("closing", fd)
        //     val _ = close0_exn(fd)
        // }
    }
    val _ = if isclose then {
        val () = unregister_watcher(e, fd)
        // val () = println!("closing", fd)
        val _ = close0_exn(fd)
    }
}

fun accept_conn(e: !Epoll, w: !Watcher, evs: uint): void = () where {
    // val () = println!("accept threadid: ", athread_self())
    // val () = println! "Accepted"
    val fd = watcher_get_fd(w)
    fun loop(e: !Epoll): void = {
        val conn = $extfcall(int, "accept", fd, 0, 0)
        val conn = g1ofg0 conn
        val () = if conn > 0 then () where {
            val _ = setnonblocking(conn)
            val w = make_watcher(conn, do_read)
            val () = register_watcher(e, w, EPOLLIN lor EPOLLET)// lor EPOLLRDHUP lor EPOLLHUP)
            val () = loop(e)
        }
    }
    val () = loop(e)
}

implement main(argc, argv) = 0 where {
    val epoll = make_epoll()
    val s = get_server()
    val () = assertloc(s > 0)
    val () = listen(s)
    val () = println!("Server fd: ", s)
    val watcher = make_watcher(s, accept_conn)
    val () = register_watcher(epoll, watcher, EPOLLIN lor EPOLLET)
    fun loop(i: int, ls: &List_vt(tid) >> _): void = {
        val () = if i > 0 then {
            val id = athread_create_cloptr_join_exn(llam() => {
                val e = make_epoll()
                val () = listen(s)
                val watcher = make_watcher(s, accept_conn)
                val () = register_watcher(e, watcher, EPOLLIN lor EPOLLET)
                val () = run(e)
                val () = free_epoll(e)
            })
            val () = assertloc(list_vt_length(ls) >= 0)
            val () = ls := list_vt_cons(id, ls)
            val () = loop(i-1, ls)
        }
    }
    var n = list_vt_nil()
    val () = loop(4, n)
    val () = list_vt_foreach(n) where {
        implement list_vt_foreach$fwork<tid><void>(t, e) = {
            val () = athread_join(t)
        }
    }
    val () = list_vt_free(n)
    val () = run(epoll)
    val () = free_epoll(epoll)
}
