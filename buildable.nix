{ pkgs ? import <nixpkgs> {} }:

let
  filterSet =
    (f: g: s: builtins.listToAttrs
      (map
        (n: { name = n; value = builtins.getAttr n s; })
        (builtins.filter
          (n: f n && g (builtins.getAttr n s))
          (builtins.attrNames s)
        )
      )
    );
  isReserved = n: builtins.elem n ["lib" "overlays" "modules"];
  isBroken = p: ({ meta.broken = false; } // p).meta.broken;
  isFree = p: ({ meta.license.free = true; } // p).meta.license.free;
in filterSet
     (n: !(isReserved n)) # filter out non-packages
     (p: (builtins.isAttrs p)
       && !(isBroken p)
       && isFree p
     )
     (import ./default.nix { inherit pkgs; })

