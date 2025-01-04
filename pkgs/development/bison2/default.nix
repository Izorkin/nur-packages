{ lib, stdenv, fetchurl, m4, perl }:

# Note: this package is used for bootstrapping fetchurl, and thus
# cannot use fetchpatch! All mutable patches (generated by GitHub or
# cgit) that are needed here should be included directly in Nixpkgs as
# files.

stdenv.mkDerivation rec {
  pname = "bison";
  version = "2.7.1";

  src = fetchurl {
    url = "mirror://gnu/bison/${pname}-${version}.tar.gz";
    sha256 = "0c9li3iaslzzr3zig6m3zlmb4r8i0wfvkcrvdyiqxasb09mjkqh8";
  };

  nativeBuildInputs = [ m4 ];
  propagatedBuildInputs = [ m4 ];
  checkInputs = [ perl ];

  patches = [
    ./patch/fix_fseterr_c.patch
  ] ++ lib.optional stdenv.hostPlatform.isDarwin ./patch/darwin-vasnprintf.patch;

  doCheck = true;
  # M4 = "${m4}/bin/m4";

  meta = {
    homepage = "https://www.gnu.org/software/bison/";
    description = "Yacc-compatible parser generator";
    license = lib.licenses.gpl3Plus;

    longDescription = ''
      Bison is a general-purpose parser generator that converts an
      annotated context-free grammar into an LALR(1) or GLR parser for
      that grammar.  Once you are proficient with Bison, you can use
      it to develop a wide range of language parsers, from those used
      in simple desk calculators to complex programming languages.

      Bison is upward compatible with Yacc: all properly-written Yacc
      grammars ought to work with Bison with no change.  Anyone
      familiar with Yacc should be able to use Bison with little
      trouble.  You need to be fluent in C or C++ programming in order
      to use Bison.
    '';

    platforms = lib.platforms.unix;
  };

  passthru = { glrSupport = true; };
}
