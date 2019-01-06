{ stdenv, zsh-command-time, zsh-theme-rkj-mod }:

stdenv.mkDerivation rec {
  name = "oh-my-zsh-custom";
  src = ./.;
  phases = [ "installPhase" ];
  installPhase = ''
    install -Dm0444 ${zsh-command-time}/share/zsh/plugins/command-time/command-time.plugin.zsh --target-directory=$out/plugins/command-time
    install -Dm0444 ${zsh-theme-rkj-mod}/share/zsh/themes/rkj-mod.zsh-theme --target-directory=$out/themes
  '';
}
