{ pkgs, fetchgit, php, openssl, libevent, libcouchbase }:

let
  self = with self; {
    buildPecl = import ./build-pecl.nix {
      inherit php;
      inherit (pkgs) stdenv autoreconfHook fetchurl re2c;
    };

    # Wrap mkDerivation to prepend pname with "php-" to make names consistent
    # with how buildPecl does it and make the file easier to overview.
    mkDerivation = { pname, ... }@args: pkgs.stdenv.mkDerivation (args // {
      pname = "php-${pname}";
    });

    isPhp56 = pkgs.lib.versionOlder   php.version "7.0";
    isPhp71 = pkgs.lib.versionAtLeast php.version "7.1";
    isPhp72 = pkgs.lib.versionAtLeast php.version "7.2";
    isPhp73 = pkgs.lib.versionAtLeast php.version "7.3";

  apcu = if isPhp56 then apcu40 else apcu51;

  #apcu40 = assert isPhp56; buildPecl rec {
  apcu40 = buildPecl rec {
    version = "4.0.11";
    pname = "apcu";

    sha256 = "002d1gklkf0z170wkbhmm2z1p9p5ghhq3q1r9k54fq1sq4p30ks5";

    buildInputs = with pkgs; [ pcre.dev ];

    meta.broken = !isPhp56;
  };

  #apcu51 = assert !isPhp56; buildPecl rec {
  apcu51 = buildPecl rec {
    version = "5.1.17";
    pname = "apcu";

    sha256 = "14y7alvj5q17q1b544bxidavkn6i40cjbq2nv1m0k70ai5vv84bb";

    buildInputs = with pkgs; [ (if isPhp73 then pcre2.dev else pcre.dev) ];
    doCheck = true;
    checkTarget = "test";
    checkFlagsArray = ["REPORT_EXIT_STATUS=1" "NO_INTERACTION=1"];
    makeFlags = [ "phpincludedir=$(dev)/include" ];
    outputs = [ "out" "dev" ];

    meta.broken = isPhp56;
  };

  #apcu_bc = assert !isPhp56; buildPecl rec {
  apcu_bc = buildPecl rec {
    version = "1.0.5";
    pname = "apcu_bc";

    sha256 = "0ma00syhk2ps9k9p02jz7rii6x3i2p986il23703zz5npd6y9n20";

    buildInputs = with pkgs; [ apcu (if isPhp73 then pcre2.dev else pcre.dev) ];

    meta.broken = isPhp56;
  };

  #ast = assert !isPhp56; buildPecl rec {
  ast = buildPecl rec {
    version = "1.0.3";
    pname = "ast";

    sha256 = "1sk9bkyw3ck9jgvlazxx8zl2nv6lc0gq66v1rfcby9v0zyydb7xr";

    meta.broken = isPhp56;
  };

  box = mkDerivation rec {
    version = "2.7.5";
    pname = "box";

    src = pkgs.fetchurl {
      url = "https://github.com/box-project/box2/releases/download/${version}/box-${version}.phar";
      sha256 = "1zmxdadrv0i2l8cz7xb38gnfmfyljpsaz2nnkjzqzksdmncbgd18";
    };

    phases = [ "installPhase" ];
    nativeBuildInputs = with pkgs; [ makeWrapper ];

    installPhase = ''
      mkdir -p $out/bin
      install -D $src $out/libexec/box/box.phar
      makeWrapper ${php}/bin/php $out/bin/box \
        --add-flags "-d phar.readonly=0 $out/libexec/box/box.phar"
    '';

    meta = with pkgs.lib; {
      description = "An application for building and managing Phars";
      license = licenses.mit;
      homepage = https://box-project.github.io/box2/;
      maintainers = with maintainers; [ jtojnar ];
    };
  };

  composer = mkDerivation rec {
    version = "1.9.0";
    pname = "composer";

    src = pkgs.fetchurl {
      url = "https://getcomposer.org/download/${version}/composer.phar";
      sha256 = "0x88bin1c749ajymz2cqjx8660a3wxvndpv4xr6w3pib16fzdpy9";
    };

    unpackPhase = ":";

    nativeBuildInputs = with pkgs; [ makeWrapper ];

    installPhase = ''
      mkdir -p $out/bin
      install -D $src $out/libexec/composer/composer.phar
      makeWrapper ${php}/bin/php $out/bin/composer \
        --add-flags "$out/libexec/composer/composer.phar" \
        --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.unzip ]}
    '';

    meta = with pkgs.lib; {
      description = "Dependency Manager for PHP";
      license = licenses.mit;
      homepage = https://getcomposer.org/;
      maintainers = with maintainers; [ globin offline ];
    };
  };

  couchbase = buildPecl rec {
    version = "2.6.1";
    pname = "couchbase";

    buildInputs = with pkgs; [ libcouchbase zlib igbinary pcs ];

    src = pkgs.fetchFromGitHub {
      owner = "couchbase";
      repo = "php-couchbase";
      rev = "v${version}";
      sha256 = "0jdzgcvab1vpxai23brmmvizjjq2d2dik9aklz6bzspfb512qjd6";
    };

    configureFlags = [ "--with-couchbase" ];

    patches = with pkgs; [
      (pkgs.writeText "php-couchbase.patch" ''
        --- a/config.m4
        +++ b/config.m4
        @@ -9,7 +9,7 @@ if test "$PHP_COUCHBASE" != "no"; then
             LIBCOUCHBASE_DIR=$PHP_COUCHBASE
           else
             AC_MSG_CHECKING(for libcouchbase in default path)
        -    for i in /usr/local /usr; do
        +    for i in ${libcouchbase}; do
               if test -r $i/include/libcouchbase/couchbase.h; then
                 LIBCOUCHBASE_DIR=$i
                 AC_MSG_RESULT(found in $i)
        @@ -154,6 +154,8 @@ COUCHBASE_FILES=" \
             igbinary_inc_path="$phpincludedir"
           elif test -f "$phpincludedir/ext/igbinary/igbinary.h"; then
             igbinary_inc_path="$phpincludedir"
        +  elif test -f "${igbinary.dev}/include/ext/igbinary/igbinary.h"; then
        +    igbinary_inc_path="${igbinary.dev}/include"
           fi
           if test "$igbinary_inc_path" = ""; then
             AC_MSG_WARN([Cannot find igbinary.h])
      '')
    ];
  };

  geoip = buildPecl rec {
    version = "1.1.1";
    pname = "geoip";

    sha256 = "01hgijn91an7gf0fva5fk3paag6lvfh7ynlv4if16ilx041mrl5j";

    configureFlags = with pkgs; [
      "--with-geoip=${geoip}"
    ];

    buildInputs = with pkgs; [ geoip ];
  };

  event = buildPecl rec {
    version = "2.5.3";
    pname = "event";

    sha256 = "12liry5ldvgwp1v1a6zgfq8w6iyyxmsdj4c71bp157nnf58cb8hb";

    configureFlags = with pkgs; [
      "--with-event-libevent-dir=${libevent.dev}"
      "--with-event-core"
      "--with-event-extra"
      "--with-event-pthreads"
    ];

    nativeBuildInputs = with pkgs; [ pkgconfig ];
    buildInputs = with pkgs; [ openssl libevent ];

    meta = with pkgs.lib; {
      description = ''
        This is an extension to efficiently schedule I/O, time and signal based
        events using the best I/O notification mechanism available for specific platform.
      '';
      license = licenses.php301;
      homepage = "https://bitbucket.org/osmanov/pecl-event/";
    };
  };

  igbinary = if isPhp56 then igbinary20 else igbinary30;

  #igbinary20 = assert isPhp56; buildPecl rec {
  igbinary20 = buildPecl rec {
    version = "2.0.8";
    pname = "igbinary";

    sha256 = "105nyn703k9p9c7wwy6npq7xd9mczmmlhyn0gn2v2wz0f88spjxs";

    configureFlags = [
      "--enable-igbinary"
    ];

    makeFlags = [ "phpincludedir=$(dev)/include" ];
    outputs = [ "out" "dev" ];

    meta.broken = !isPhp56;
  };

  #igbinary30 = assert !isPhp56; buildPecl rec {
  igbinary30 = buildPecl rec {
    version = "3.0.1";
    pname = "igbinary";

    sha256 = "1w8jmf1qpggdvq0ndfi86n7i7cqgh1s8q6hys2lijvi37rzn0nar";

    configureFlags = [
      "--enable-igbinary"
    ];

    makeFlags = [ "phpincludedir=$(dev)/include" ];
    outputs = [ "out" "dev" ];

    meta.broken = isPhp56;
  };

  imagick = buildPecl rec {
    version = "3.4.4";
    pname = "imagick";

    sha256 = "0xvhaqny1v796ywx83w7jyjyd0nrxkxf34w9zi8qc8aw8qbammcd";

    configureFlags = with pkgs; [
      "--with-imagick=${imagemagick.dev}"
    ];

    nativeBuildInputs = with pkgs; [ pkgconfig ];
    buildInputs = with pkgs; [ (if isPhp73 then pcre2.dev else pcre.dev) ];
  };

  #mailparse = assert !isPhp56; assert !isPhp73; buildPecl rec {
  mailparse = buildPecl rec {
    version = "3.0.3";
    pname = "mailparse";

    sha256 = "00nk14jbdbln93mx3ag691avc11ff94hkadrcv5pn51c6ihsxbmz";

    meta.broken = isPhp56;
  };

  #memcache = assert isPhp56; buildPecl rec {
  memcache = buildPecl rec {
    version = "3.0.8";
    pname = "memcache";

    sha256 = "04c35rj0cvq5ygn2jgmyvqcb0k8d03v4k642b6i37zgv7x15pbic";

    configureFlags = with pkgs; [
      "--with-zlib-dir=${zlib.dev}"
    ];

    makeFlags = [ "CFLAGS=-fgnu89-inline" ];

    meta.broken = !isPhp56;
  };

  memcached = if isPhp56 then memcached22 else memcached31;

  #memcached22 = assert isPhp56; buildPecl rec {
  memcached22 = buildPecl rec {
    version = "2.2.0";
    pname = "memcached";

    sha256 = "0n4z2mp4rvrbmxq079zdsrhjxjkmhz6mzi7mlcipz02cdl7n1f8p";

    configureFlags = with pkgs; [
      "--with-zlib-dir=${zlib.dev}"
      "--with-libmemcached-dir=${libmemcached}"
    ];

    nativeBuildInputs = with pkgs; [ pkgconfig ];
    buildInputs = with pkgs; [ cyrus_sasl zlib ];

    meta.broken = !isPhp56;
  };

  #memcached31 = assert !isPhp56; buildPecl rec {
  memcached31 = buildPecl rec {
    version = "3.1.3";
    pname = "memcached";

    src = fetchgit {
      url = "https://github.com/php-memcached-dev/php-memcached";
      rev = "v${version}";
      sha256 = "1w9g8k7bmq3nbzskskpsr5632gh9q75nqy7nkjdzgs17klq9khjk";
    };

    configureFlags = with pkgs; [
      "--with-zlib-dir=${zlib.dev}"
      "--with-libmemcached-dir=${libmemcached}"
    ];

    nativeBuildInputs = with pkgs; [ pkgconfig ];
    buildInputs = with pkgs; [ cyrus_sasl zlib ];

    meta.broken = isPhp56;
  };

  pcs = buildPecl rec {
    version = "1.3.3";
    pname = "pcs";

    sha256 = "0d4p1gpl8gkzdiv860qzxfz250ryf0wmjgyc8qcaaqgkdyh5jy5p";
  };

  #pdo_sqlsrv = assert !isPhp56; buildPecl rec {
  pdo_sqlsrv = buildPecl rec {
    version = "5.6.1";
    pname = "pdo_sqlsrv";

    sha256 = "02ill1iqffa5fha9iz4y91823scml24ikfk8pn90jyycfwv07x6a";

    buildInputs = with pkgs; [ unixODBC ];

    meta.broken = isPhp56;
  };

  php-cs-fixer = mkDerivation rec {
    version = "2.15.1";
    pname = "php-cs-fixer";

    src = pkgs.fetchurl {
      url = "https://github.com/FriendsOfPHP/PHP-CS-Fixer/releases/download/v${version}/php-cs-fixer.phar";
      sha256 = "0qbqdki6vj8bgj5m2k4mi0qgj17r6s2v2q7yc30hhgvksf7vamlc";
    };

    phases = [ "installPhase" ];
    nativeBuildInputs = with pkgs; [ makeWrapper ];

    installPhase = ''
      mkdir -p $out/bin
      install -D $src $out/libexec/php-cs-fixer/php-cs-fixer.phar
      makeWrapper ${php}/bin/php $out/bin/php-cs-fixer \
        --add-flags "$out/libexec/php-cs-fixer/php-cs-fixer.phar"
    '';

    meta = with pkgs.lib; {
      description = "A tool to automatically fix PHP coding standards issues";
      license = licenses.mit;
      homepage = http://cs.sensiolabs.org/;
      maintainers = with maintainers; [ jtojnar ];
    };
  };

  php-parallel-lint = mkDerivation rec {
    version = "1.0.0";
    pname = "php-parallel-lint";

    src = pkgs.fetchFromGitHub {
      owner = "JakubOnderka";
      repo = "PHP-Parallel-Lint";
      rev = "v${version}";
      sha256 = "16nv8yyk2z3l213dg067l6di4pigg5rd8yswr5xgd18jwbys2vnw";
    };

    nativeBuildInputs = with pkgs; [ makeWrapper ];
    buildInputs = [ composer box ];

    buildPhase = ''
      composer dump-autoload
      box build
    '';

    installPhase = ''
      mkdir -p $out/bin
      install -D parallel-lint.phar $out/libexec/php-parallel-lint/php-parallel-lint.phar
      makeWrapper ${php}/bin/php $out/bin/php-parallel-lint \
        --add-flags "$out/libexec/php-parallel-lint/php-parallel-lint.phar"
    '';

    meta = with pkgs.lib; {
      description = "This tool check syntax of PHP files faster than serial check with fancier output";
      license = licenses.bsd2;
      homepage = https://github.com/JakubOnderka/PHP-Parallel-Lint;
      maintainers = with maintainers; [ jtojnar ];
    };
  };

  phpcbf = mkDerivation rec {
    version = "3.4.2";
    pname = "phpcbf";

    src = pkgs.fetchurl {
      url = "https://github.com/squizlabs/PHP_CodeSniffer/releases/download/${version}/phpcbf.phar";
      sha256 = "08s47r8i5dyjivk1q3nhrz40n6fx3zghrn5irsxfnx5nj9pb7ffp";
    };

    phases = [ "installPhase" ];
    nativeBuildInputs = with pkgs; [ makeWrapper ];

    installPhase = ''
      mkdir -p $out/bin
      install -D $src $out/libexec/phpcbf/phpcbf.phar
      makeWrapper ${php}/bin/php $out/bin/phpcbf \
        --add-flags "$out/libexec/phpcbf/phpcbf.phar"
    '';

    meta = with pkgs.lib; {
      description = "PHP coding standard beautifier and fixer";
      license = licenses.bsd3;
      homepage = https://squizlabs.github.io/PHP_CodeSniffer/;
      maintainers = with maintainers; [ cmcdragonkai etu ];
    };
  };

  phpcs = mkDerivation rec {
    version = "3.4.2";
    pname = "phpcs";

    src = pkgs.fetchurl {
      url = "https://github.com/squizlabs/PHP_CodeSniffer/releases/download/${version}/phpcs.phar";
      sha256 = "0hk9w5kn72z9xhswfmxilb2wk96vy07z4a1pwrpspjlr23aajrk9";
    };

    phases = [ "installPhase" ];
    nativeBuildInputs = with pkgs; [ makeWrapper ];

    installPhase = ''
      mkdir -p $out/bin
      install -D $src $out/libexec/phpcs/phpcs.phar
      makeWrapper ${php}/bin/php $out/bin/phpcs \
        --add-flags "$out/libexec/phpcs/phpcs.phar"
    '';

    meta = with pkgs.lib; {
      description = "PHP coding standard tool";
      license = licenses.bsd3;
      homepage = https://squizlabs.github.io/PHP_CodeSniffer/;
      maintainers = with maintainers; [ javaguirre etu ];
    };
  };

  phpstan = mkDerivation rec {
    version = "0.11.12";
    pname = "phpstan";

    src = pkgs.fetchurl {
      url = "https://github.com/phpstan/phpstan/releases/download/${version}/phpstan.phar";
      sha256 = "12k74108f7a3k7ms8n4c625vpxrq75qamw1k1q09ndzmbn3i7c9b";
    };

    phases = [ "installPhase" ];
    nativeBuildInputs = with pkgs; [ makeWrapper ];

    installPhase = ''
      mkdir -p $out/bin
      install -D $src $out/libexec/phpstan/phpstan.phar
      makeWrapper ${php}/bin/php $out/bin/phpstan \
        --add-flags "$out/libexec/phpstan/phpstan.phar"
    '';

    meta = with pkgs.lib; {
      description = "PHP Static Analysis Tool";
      longDescription = ''
        PHPStan focuses on finding errors in your code without actually running
        it. It catches whole classes of bugs even before you write tests for the
        code. It moves PHP closer to compiled languages in the sense that the
        correctness of each line of the code can be checked before you run the
        actual line.
      '';
      license = licenses.mit;
      homepage = https://github.com/phpstan/phpstan;
      maintainers = with maintainers; [ etu ];
    };
  };

  pinba = if isPhp56 then pinba110 else (if isPhp73 then pinba112 else pinba111 );

  pinba110 = buildPecl rec {
    version = "1.1.0";
    pname = "pinba";

    src = pkgs.fetchFromGitHub {
      owner = "tony2001";
      repo = "pinba_extension";
      rev = "7e7cd25ebcd74234f058bfe350128238383c6b96";
      sha256 = "1866c82ypijcm44sbfygfzs0d3klj7xsyc40imzac7s9x1x4fp81";
    };

    meta = with pkgs.lib; {
      description = "PHP extension for Pinba";
      longDescription = ''
        Pinba is a MySQL storage engine that acts as a realtime monitoring and
        statistics server for PHP using MySQL as a read-only interface.
      '';
      homepage = "http://pinba.org/";

      broken = !isPhp56;
    };
  };

  #pinba111 = assert !isPhp56; assert !isPhp73; buildPecl rec {
  pinba111 = buildPecl rec {
    version = "1.1.1";
    pname = "pinba";

    src = pkgs.fetchFromGitHub {
      owner = "tony2001";
      repo = "pinba_extension";
      rev = "RELEASE_1_1_1";
      sha256 = "1kdp7vav0y315695vhm3xifgsh6h6y6pny70xw3iai461n58khj5";
    };

    meta = with pkgs.lib; {
      description = "PHP extension for Pinba";
      longDescription = ''
        Pinba is a MySQL storage engine that acts as a realtime monitoring and
        statistics server for PHP using MySQL as a read-only interface.
      '';
      homepage = "http://pinba.org/";

      broken = (isPhp56 || isPhp73);
    };
  };

  #pinba112 = assert !isPhp56; assert isPhp73; buildPecl rec {
  pinba112 = buildPecl rec {
    version = "1.1.2-dev";
    pname = "pinba";

    src = pkgs.fetchFromGitHub {
      owner = "tony2001";
      repo = "pinba_extension";
      rev = "edbc313f1b4fb8407bf7d5acf63fbb0359c7fb2e";
      sha256 = "02sljqm6griw8ccqavl23f7w1hp2zflcv24lpf00k6pyrn9cwx80";
    };

    meta = with pkgs.lib; {
      description = "PHP extension for Pinba";
      longDescription = ''
        Pinba is a MySQL storage engine that acts as a realtime monitoring and
        statistics server for PHP using MySQL as a read-only interface.
      '';
      homepage = "http://pinba.org/";

      broken = (isPhp56 || !isPhp73);
    };
  };

  protobuf = buildPecl rec {
    version = "3.9.0";
    pname = "protobuf";

    sha256 = "1pyfxrfdbzzg5al4byyazdrvy7yad13zwq7papbb2d8gkvc3f3kh";

    buildInputs = with pkgs; [ (if isPhp73 then pcre2.dev else pcre.dev) ];

    meta = with pkgs.lib; {
      description = ''
        Google's language-neutral, platform-neutral, extensible mechanism for serializing structured data.
      '';
      license = licenses.bsd3;
      homepage = "https://developers.google.com/protocol-buffers/";
    };
  };

  psysh = mkDerivation rec {
    version = "0.9.9";
    pname = "psysh";

    src = pkgs.fetchurl {
      url = "https://github.com/bobthecow/psysh/releases/download/v${version}/psysh-v${version}.tar.gz";
      sha256 = "0knbib0afwq2z5fc639ns43x8pi3kmp85y13bkcl00dhvf46yinw";
    };

    phases = [ "installPhase" ];
    nativeBuildInputs = with pkgs; [ makeWrapper ];

    installPhase = ''
      mkdir -p $out/bin
      tar -xzf $src -C $out/bin
      chmod +x $out/bin/psysh
      wrapProgram $out/bin/psysh
    '';

    meta = with pkgs.lib; {
      description = "PsySH is a runtime developer console, interactive debugger and REPL for PHP.";
      license = licenses.mit;
      homepage = https://psysh.org/;
      maintainers = with maintainers; [ caugner ];
    };
  };

  pthreads = if isPhp56 then pthreads20 else (if isPhp73 then pthreads32-dev else (if isPhp72 then pthreads32 else pthreads31));

  #pthreads20 = assert isPhp56; buildPecl rec {
  pthreads20 = buildPecl rec {
    version = "2.0.10";
    pname = "pthreads";

    sha256 = "1xlcb1b1g10jd0xhm3c01a06yqpb5qln47pd1k522138324qvpwb";

    buildInputs = with pkgs; [ pcre.dev ];

    meta.broken = !isPhp56;
  };

  #pthreads31 = assert isPhp71; assert !isPhp72; buildPecl rec {
  pthreads31 = buildPecl rec {
    version = "3.1.6-dev";
    pname = "pthreads";

    src = pkgs.fetchFromGitHub {
      owner = "krakjoe";
      repo = "pthreads";
      rev = "527286336ffcf5fffb285f1bfeb100bb8bf5ec32";
      sha256 = "0p2kkngmnw4lk2lshgq7hx91wqn21yjxzqlx90xcv94ysvffspl5";
    };

    buildInputs = with pkgs; [ pcre.dev ];

    meta.broken = (!isPhp71 || isPhp72 || isPhp73);
  };

  #pthreads32 = assert isPhp72; assert !isPhp73; buildPecl rec {
  pthreads32 = buildPecl rec {
    version = "3.2.0";
    pname = "pthreads";

    src = pkgs.fetchFromGitHub {
      owner = "krakjoe";
      repo = "pthreads";
      rev = "v${version}";
      sha256 = "17hypm75d4w7lvz96jb7s0s87018yzmmap0l125d5fd7abnhzfvv";
    };

    buildInputs = with pkgs; [ pcre.dev ];

    meta.broken = (!isPhp72 || isPhp73);
  };

  #pthreads32-dev = assert isPhp73; buildPecl rec {
  pthreads32-dev = buildPecl rec {
    version = "3.2.0-dev";
    pname = "pthreads";

    src = pkgs.fetchFromGitHub {
      owner = "krakjoe";
      repo = "pthreads";
      rev = "4d1c2483ceb459ea4284db4eb06646d5715e7154";
      sha256 = "07kdxypy0bgggrfav2h1ccbv67lllbvpa3s3zsaqci0gq4fyi830";
    };

    buildInputs = with pkgs; [ pcre2.dev ];

    meta.broken = !isPhp73;
  };

  redis = if isPhp56 then redis43 else redis50;

  #redis43 = assert isPhp56; buildPecl rec {
  redis43 = buildPecl rec {
    version = "4.3.0";
    pname = "redis";

    sha256 = "18hvll173mlp6dk6xvgajkjf4min8f5gn809nr1ahq4r6kn4rw60";

    meta.broken = !isPhp56;
  };

  #redis50 = assert !isPhp56; buildPecl rec {
  redis50 = buildPecl rec {
    version = "5.0.2";
    pname = "redis";

    sha256 = "0b5pw17lzqknhijfymksvf8fm1zilppr97ypb31n599jw3mxf62f";

    meta.broken = isPhp56;
  };

  #sqlsrv = assert !isPhp56; buildPecl rec {
  sqlsrv = buildPecl rec {
    version = "5.6.1";
    pname = "sqlsrv";

    sha256 = "0ial621zxn9zvjh7k1h755sm2lc9aafc389yxksqcxcmm7kqmd0a";

    buildInputs = with pkgs; [ unixODBC ];

    meta.broken = isPhp56;
  };

  #spidermonkey = assert isPhp56; buildPecl rec {
  spidermonkey = buildPecl rec {
    version = "1.0.0";
    pname = "spidermonkey";

    sha256 = "1ywrsp90w6rlgq3v2vmvp2zvvykkgqqasab7h9bf3vgvgv3qasbg";

    configureFlags = with pkgs; [
      "--with-spidermonkey=${spidermonkey_1_8_5}"
    ];

    buildInputs = with pkgs; [ spidermonkey_1_8_5 ];

    meta.broken = !isPhp56;
  };

  #xcache = assert isPhp56; buildPecl rec {
  xcache = buildPecl rec {
    version = "3.2.0";
    pname = "xcache";

    src = pkgs.fetchurl {
      url = "http://xcache.lighttpd.net/pub/Releases/${version}/${pname}.tar.bz2";
      sha256 = "1gbcpw64da9ynjxv70jybwf9y88idm01kb16j87vfagpsp5s64kx";
    };

    doCheck = true;
    checkTarget = "test";

    configureFlags = [
      "--enable-xcache"
      "--enable-xcache-coverager"
      "--enable-xcache-optimizer"
      "--enable-xcache-assembler"
      "--enable-xcache-encoder"
      "--enable-xcache-decoder"
    ];

    buildInputs = with pkgs; [ m4 ];

    meta.broken = !isPhp56;
  };

  xdebug = if isPhp56 then xdebug25 else xdebug27;

  #xdebug25 = assert isPhp56; buildPecl rec {
  xdebug25 = buildPecl rec {
    version = "2.5.5";
    pname = "xdebug";

    sha256 = "197i1fcspbrdxki6rljvpjdxzhyaxl7nlihhiqcyfkjipkr8n43j";

    doCheck = true;
    checkTarget = "test";

    meta.broken = !isPhp56;
  };

  #xdebug27 = assert !isPhp56; buildPecl rec {
  xdebug27 = buildPecl rec {
    version = "2.7.2";
    pname = "xdebug";

    sha256 = "19m40n5h339yk0g458zpbsck1lslhnjsmhrp076kzhl5l4x2iwxh";

    doCheck = true;
    checkTarget = "test";

    meta.broken = isPhp56;
  };

  yaml = if isPhp56 then yaml13 else yaml20;

  #yaml13 = assert isPhp56; buildPecl rec {
  yaml13 = buildPecl rec {
    version = "1.3.2";
    pname = "yaml";

    sha256 = "16jr5v3pff3f1yd61hh4pb279ivb7np1kf8mhvfw16g0fsvx33js";

    configureFlags = with pkgs; [
      "--with-yaml=${libyaml}"
    ];

    nativeBuildInputs = with pkgs; [ pkgconfig ];

    meta.broken = !isPhp56;
  };

  #yaml20 = assert !isPhp56; buildPecl rec {
  yaml20 = buildPecl rec {
    version = "2.0.4";
    pname = "yaml";

    sha256 = "1036zhc5yskdfymyk8jhwc34kvkvsn5kaf50336153v4dqwb11lp";

    configureFlags = with pkgs; [
      "--with-yaml=${libyaml}"
    ];

    nativeBuildInputs = with pkgs; [ pkgconfig ];

    meta.broken = isPhp56;
  };

  #zmq = assert !isPhp73; buildPecl rec {
  zmq = buildPecl rec {
    version = "1.1.3";
    pname = "zmq";

    sha256 = "1kj487vllqj9720vlhfsmv32hs2dy2agp6176mav6ldx31c3g4n4";

    configureFlags = with pkgs; [
      "--with-zmq=${zeromq}"
    ];

    nativeBuildInputs = with pkgs; [ pkgconfig ];

    meta.broken = isPhp73;
  };
}; in self
