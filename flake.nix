{
  description = "A truely cross platform GUI toolkit for Zig.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
    zig-overlay.url = "github:mitchellh/zig-overlay";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-parts,
      systems,
      zig-overlay,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import systems;

      flake.overlays.default = final: prev: {
        zig_0_15 = final.zigpkgs.master.overrideAttrs (
          f: p: {
            inherit (final.zig_0_13) meta;

            passthru.hook = final.callPackage "${nixpkgs}/pkgs/development/compilers/zig/hook.nix" {
              zig = f.finalPackage;
            };
          }
        );
      };

      perSystem =
        {
          config,
          pkgs,
          system,
          ...
        }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [
              self.overlays.default
              zig-overlay.overlays.default
            ];
            config = { };
          };

          legacyPackages = pkgs;

          devShells =
            let
              optionalPackage' =
                pkgs: pkg: pkgs.lib.optional (pkgs.lib.meta.availableOn pkgs.hostPlatform pkg) pkg;
              mkShell =
                pkgs:
                pkgs.mkShell {
                  packages =
                    let
                      optionalPackage = optionalPackage' pkgs;
                    in
                    with pkgs;
                    [
                      buildPackages.zon2nix
                      buildPackages.zig_0_14
                    ];
                };
            in
            {
              default = mkShell pkgs;
              cross-aarch64-linux = mkShell pkgs.pkgsCross.aarch64-multiplatform;
              cross-x86_64-linux = mkShell pkgs.pkgsCross.gnu64;
              cross-riscv64-linux = mkShell pkgs.pkgsCross.riscv64;
            };
        };
    };
}
