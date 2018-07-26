{ stdenv }:

stdenv.mkDerivation rec {
  name = "oh-my-zsh-custom";
  src = ./.;
  installPhase = ''
    install -Dm444 $src/themes/rkj-mod.zsh-theme --target-directory=$out/themes
  '';
}