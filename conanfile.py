from atsconan import ATSConan

class ATSConan(ATSConan):
    name = "ats-epoll"
    version = "0.2.1"
    requires = "linmap-list-vt/0.2@randy.valis/testing", "hashtable-vt/0.2@randy.valis/testing"

    def package_info(self):
        super().package_info()
        self.cpp_info.libs = ["ats-epoll"]
