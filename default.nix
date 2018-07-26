{ pkgs ? import <nixpkgs> {} }:

rec {
  lib = import ./lib { inherit pkgs; };
  modules = import ./modules;
  overlays = import ./overlays;

  multichain       = pkgs.callPackage ./pkgs/apps/altcoins/multichain.nix { };
  omnicore         = pkgs.callPackage ./pkgs/apps/altcoins/omnicore.nix { };
  oh-my-zsh-custom = pkgs.callPackage ./pkgs/shells/oh-my-zsh-custom { };
  fail2ban         = pkgs.callPackage ./pkgs/tools/fail2ban { };
}

