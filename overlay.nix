self: super:

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
in filterSet
     (n: !(isReserved n)) # filter out non-packages
     (p: true) # all packages are ok
     (import ./default.nix { pkgs = super; })

