{ lib, stdenv, fetchFromGitHub, buildEnv
, asio, boost, check, openssl, cmake
}:

stdenv.mkDerivation rec {
  pname = "mariadb-galera";
  version = "25.3.35";

  src = fetchFromGitHub {
    owner = "codership";
    repo = "galera";
    rev = "release_${version}";
    sha256 = "sha256-M7Zj6+IVUhBDlDEk3gErw74zAofhQRvkNRtIc5Z8zGQ=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [ cmake ];

  buildInputs = [ asio boost.dev check openssl ];

  preConfigure = ''
    # make sure bundled asio cannot be used, but leave behind license, because it gets installed
    rm -r asio/{asio,asio.hpp}
  '';

  postInstall = ''
    # for backwards compatibility
    mkdir $out/lib/galera
    ln -s $out/lib/libgalera_smm.so $out/lib/galera/libgalera_smm.so
  '';

  meta = with lib; {
    description = "Galera 3 wsrep provider library";
    homepage = "https://galeracluster.com/";
    license = licenses.lgpl2Only;
    maintainers = with maintainers; [ izorkin ];
    platforms = platforms.all;
  };
}
