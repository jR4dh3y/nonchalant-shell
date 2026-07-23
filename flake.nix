{
  description = "Nonchalant Shell — a Niri-first Wayland desktop shell built with Quickshell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    axctl = {
      url = "github:Axenide/axctl";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, axctl, ... }:
    let
      nonchalantLib = import ./nix/lib.nix { inherit nixpkgs; };
      version = nixpkgs.lib.removeSuffix "\n" (builtins.readFile ./version);
    in {
      nixosModules.default = { pkgs, lib, ... }: {
        imports = [ ./nix/modules ];
        programs.nonchalant.enable = lib.mkDefault true;
        programs.nonchalant.package = lib.mkDefault self.packages.${pkgs.system}.default;
      };

      packages = nonchalantLib.forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          lib = nixpkgs.lib;

          Nonchalant = import ./nix/packages {
            inherit pkgs lib self system axctl version;
          };
        in {
          default = Nonchalant;
          Nonchalant = Nonchalant;
        }
      );

      devShells = nonchalantLib.forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          Nonchalant = self.packages.${system}.default;
        in {
          default = pkgs.mkShell {
            packages = [ Nonchalant ];
            shellHook = ''
              export QML2_IMPORT_PATH="${Nonchalant}/lib/qt-6/qml:$QML2_IMPORT_PATH"
              export QML_IMPORT_PATH="$QML2_IMPORT_PATH"
              echo "Nonchalant Shell dev environment loaded."
            '';
          };
        }
      );

      apps = nonchalantLib.forAllSystems (system:
        let
          Nonchalant = self.packages.${system}.default;
        in {
          default = {
            type = "app";
            program = "${Nonchalant}/bin/nonchalant";
          };
        }
      );
    };
}
