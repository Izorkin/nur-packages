{ lib, stdenv, fetchurl, pkg-config, perl
, http2Support ? true, nghttp2
, idnSupport ? false, libidn2 ? null
, ldapSupport ? false, openldap ? null
, zlibSupport ? true, zlib ? null
, zstdSupport ? false, zstd ? null
, opensslSupport ? zlibSupport, openssl ? null
, gnutlsSupport ? false, gnutls ? null
, wolfsslSupport ? false, wolfssl ? null
, scpSupport ? zlibSupport && !stdenv.isSunOS && !stdenv.isCygwin, libssh2 ? null
, gsaslSupport ? false, gsasl ? null
, gssSupport ? with stdenv.hostPlatform; (
    !isWindows &&
    # disable gss becuase of: undefined reference to `k5_bcmp'
    # a very sad story re static: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=439039
    !isStatic &&
    # the "mig" tool does not configure its compiler correctly. This could be
    # fixed in mig, but losing gss support on cross compilation to darwin is
    # not worth the effort.
    !(isDarwin && (stdenv.buildPlatform != stdenv.hostPlatform))
  ), libkrb5 ? null
, c-aresSupport ? false, c-ares ? null
, brotliSupport ? false, brotli ? null
, rtmpSupport ? false, rtmpdump ? null
, ipv6Support ? true
}:

# Note: this package is used for bootstrapping fetchurl, and thus
# cannot use fetchpatch! All mutable patches (generated by GitHub or
# cgit) that are needed here should be included directly in Nixpkgs as
# files.

assert http2Support -> nghttp2 != null;
assert idnSupport -> libidn2 != null;
assert ldapSupport -> openldap != null;
assert zlibSupport -> zlib != null;
assert zstdSupport -> zstd != null;
assert opensslSupport -> openssl != null;
assert !(gnutlsSupport && opensslSupport);
assert !(gnutlsSupport && wolfsslSupport);
assert !(opensslSupport && wolfsslSupport);
assert gnutlsSupport -> gnutls != null;
assert wolfsslSupport -> wolfssl != null;
assert scpSupport -> libssh2 != null;
assert c-aresSupport -> c-ares != null;
assert brotliSupport -> brotli != null;
assert gsaslSupport -> gsasl != null;
assert gssSupport -> libkrb5 != null;
assert rtmpSupport -> rtmpdump !=null;

stdenv.mkDerivation rec {
  pname = "curl";
  version = "7.81.0";

  src = fetchurl {
    urls = [
      "https://curl.haxx.se/download/${pname}-${version}.tar.bz2"
      "https://github.com/curl/curl/releases/download/${lib.replaceStrings ["."] ["_"] pname}-${version}/${pname}-${version}.tar.bz2"
    ];
    sha256 = "sha256-Hno41wGOwGDx8W34OYVPCInpThIsTPpdOjfC3Fbx4lg=";
  };

  patches = [
    ./patch/7.79.1-darwin-no-systemconfiguration.patch
  ];

  outputs = [ "bin" "dev" "out" "man" "devdoc" ];
  separateDebugInfo = stdenv.isLinux;

  enableParallelBuilding = true;

  strictDeps = true;

  nativeBuildInputs = [ pkg-config perl ];

  # Zlib and OpenSSL must be propagated because `libcurl.la' contains
  # "-lz -lssl", which aren't necessary direct build inputs of
  # applications that use Curl.
  propagatedBuildInputs = with lib;
    optional http2Support nghttp2 ++
    optional idnSupport libidn2 ++
    optional ldapSupport openldap ++
    optional zlibSupport zlib ++
    optional zstdSupport zstd ++
    optional gsaslSupport gsasl ++
    optional gssSupport libkrb5 ++
    optional c-aresSupport c-ares ++
    optional opensslSupport openssl ++
    optional gnutlsSupport gnutls ++
    optional wolfsslSupport wolfssl ++
    optional scpSupport libssh2 ++
    optional brotliSupport brotli ++
    optional rtmpSupport rtmpdump;

  # for the second line see https://curl.haxx.se/mail/tracker-2014-03/0087.html
  preConfigure = ''
    sed -e 's|/usr/bin|/no-such-path|g' -i.bak configure
    rm src/tool_hugehelp.c
  '';

  configureFlags = [
      # Disable default CA bundle, use NIX_SSL_CERT_FILE or fallback
      # to nss-cacert from the default profile.
      "--without-ca-bundle"
      "--without-ca-path"
      # The build fails when using wolfssl with --with-ca-fallback
      (lib.withFeature (!wolfsslSupport) "ca-fallback")
      "--disable-manual"
      (lib.withFeatureAs opensslSupport "openssl" (lib.getDev openssl))
      (lib.withFeatureAs gnutlsSupport "gnutls" (lib.getDev gnutls))
      (lib.withFeatureAs scpSupport "libssh2" (lib.getDev libssh2))
      (lib.enableFeature ldapSupport "ldap")
      (lib.enableFeature ldapSupport "ldaps")
      (lib.withFeatureAs idnSupport "libidn2" (lib.getDev libidn2))
      (lib.withFeature zstdSupport "zstd")
      (lib.withFeature brotliSupport "brotli")
      (lib.withFeature rtmpSupport "librtmp")
    ]
    ++ lib.optional wolfsslSupport "--with-wolfssl=${lib.getDev wolfssl}"
    ++ lib.optional c-aresSupport "--enable-ares=${c-ares}"
    ++ lib.optional gssSupport "--with-gssapi=${lib.getDev libkrb5}"
       # For the 'urandom', maybe it should be a cross-system option
    ++ lib.optional (stdenv.hostPlatform != stdenv.buildPlatform)
       "--with-random=/dev/urandom"
    ++ lib.optionals stdenv.hostPlatform.isWindows [
      "--disable-shared"
      "--enable-static"
    ]
    ++ lib.optional (!ipv6Support) "--disable-ipv6";

  CXX = "${stdenv.cc.targetPrefix}c++";
  CXXCPP = "${stdenv.cc.targetPrefix}c++ -E";

  doCheck = false; # expensive, fails

  postInstall = ''
    moveToOutput bin/curl-config "$dev"

    # Install completions
    make -C scripts install
  '' + lib.optionalString scpSupport ''
    sed '/^dependency_libs/s|${lib.getDev libssh2}|${lib.getLib libssh2}|' -i "$out"/lib/*.la
  '' + lib.optionalString gnutlsSupport ''
    ln $out/lib/libcurl.so $out/lib/libcurl-gnutls.so
    ln $out/lib/libcurl.so $out/lib/libcurl-gnutls.so.4
    ln $out/lib/libcurl.so $out/lib/libcurl-gnutls.so.4.4.0
  '';

  passthru = {
    inherit opensslSupport openssl;
  };

  meta = with lib; {
    description = "A command line tool for transferring files with URL syntax";
    homepage    = "https://curl.se/";
    license = licenses.curl;
    maintainers = with maintainers; [ lovek323 ];
    platforms = platforms.all;
    # Fails to link against static brotli or gss
    broken = stdenv.hostPlatform.isStatic && (brotliSupport || gssSupport);
  };
}
