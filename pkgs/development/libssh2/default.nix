{ lib, stdenv, fetchurl, openssl, zlib, windows }:

stdenv.mkDerivation rec {
  pname = "libssh2";
  version = "1.11.1";

  src = fetchurl {
    url = "${meta.homepage}/download/${pname}-${version}.tar.gz";
    sha256 = "sha256-2ex2y+NNuY7sNTn+LImdJrDIN8s+tGalaw8QnKv2WPc=";
  };

  outputs = [ "out" "dev" "devdoc" ];

  buildInputs = [ openssl zlib ]
    ++ lib.optional stdenv.hostPlatform.isMinGW windows.mingw_w64;

  meta = {
    description = "A client-side C library implementing the SSH2 protocol";
    homepage = "https://www.libssh2.org/";
    platforms = lib.platforms.all;
    maintainers = [ ];
  };
}
