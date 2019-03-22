{ stdenv, fetchurl, openssl, zlib, windows
, hostPlatform
}:

stdenv.mkDerivation rec {
  pname = "libssh2";
  version = "1.8.1";

  src = fetchurl {
    url = "${meta.homepage}/download/${pname}-${version}.tar.gz";
    sha256 = "0ngif3ynk6xqzy5nlfjs7bsmfm81g9f145av0z86kf0vbgrigda0";
  };

  outputs = [ "out" "dev" "devdoc" ];

  buildInputs = [ openssl zlib ]
    ++ stdenv.lib.optional hostPlatform.isMinGW windows.mingw_w64;

  meta = {
    description = "A client-side C library implementing the SSH2 protocol";
    homepage = https://www.libssh2.org;
    platforms = stdenv.lib.platforms.all;
    maintainers = [ ];
  };
}
