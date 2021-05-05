from conans import ConanFile, AutoToolsBuildEnvironment
from conans import tools
import os

class ATSConan(ConanFile):
    name = "ats-epoll"
    version = "0.1"
    settings = "os", "compiler", "build_type", "arch"
    # generators = "make"
    exports_sources = "*"
    options = {"shared": [True, False], "fPIC": [True, False]}
    default_options = {"shared": False, "fPIC": False}
    requires = "linmap-list-vt/0.1@randy.valis/testing", "hashtable-vt/0.1@randy.valis/testing"

    def build(self):
        atools = AutoToolsBuildEnvironment(self)
        # var = atools.vars
        # var['ATSFLAGS'] = "-IATS" + " -IATS ".join([ f"{self.deps_cpp_info[x].build_paths[0]}src" for x in self.deps_cpp_info.deps ])
        # atools.make(vars=var)
        atools.make()

    def package(self):
        self.copy("*.hats", dst="", src="")
        self.copy("*.dats", dst="", src="")
        self.copy("*.sats", dst="", src="")
        if self.options.shared:
            self.copy("*.so", dst="lib", keep_path=False)
        else:
            self.copy("*.a", dst="lib", keep_path=False)

    def package_info(self):
        self.cpp_info.libs = ["ats-epoll"]
