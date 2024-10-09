{
  description = "A set of Nix/NixOS capability demos";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    # Demo: Lock files
  };

  outputs = { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      aarch64Pkgs = pkgs.pkgsCross.aarch64-multiplatform;
      riscvPkgs = pkgs.pkgsCross.riscv64;
    in
    {

      # Basic packaging
      packages.x86_64-linux.hello = pkgs.callPackage ./hello { };

      # Cross-compilation
      packages.aarch64-linux.hello = aarch64Pkgs.callPackage ./hello { };
      packages.riscv64-linux.hello = riscvPkgs.callPackage ./hello { };

      # Shell environments
      devShells.x86_64-linux.default = pkgs.mkShell {

        # Get a cross-compilation environment.
        inputsFrom = [ self.packages.riscv64-linux.hello ];

        # Get the tools to run the resulting binary.
        packages = [ pkgs.qemu-user ];
      };

      # Overrides
      packages.x86_64-linux.helloClang = self.packages.x86_64-linux.hello.override {
        # Build with clang.
        stdenv = pkgs.clangStdenv;

        # Use a different OpenSSL version.
        openssl = pkgs.openssl_3_3;
      };

      # Patch packages. Can also be used to patch dependencies of packages (not global!).
      packages.x86_64-linux.helloPatched = self.packages.x86_64-linux.hello.overrideAttrs {
        patches = [
          ./hello/example.patch
        ];
      };

      # NixOS modules
      modules.default = { config, pkgs, lib, ... }:
        with lib;
        let
          cfg = config.services.hello;
        in
        {
          options.services.hello = {
            enable = mkEnableOption "Hello Module";

            # Allow the user to config
            package = mkOption {
              type = types.package;
              default = self.packages.x86_64-linux.hello;
              description = "What ";
            };

            harden = mkEnableOption "hardening for the systemd service";
          };

          config = mkIf cfg.enable {
            # Deploy a systemd service.
            systemd.services.hello = {
              wantedBy = [ "multi-user.target" ];

              serviceConfig.ExecStart = lib.getExe cfg.package;

              # Use config options to configure everything.
              confinement.enable = cfg.harden;
            };

            # Expose the program in PATH.
            environment.systemPackages = [
              cfg.package
            ];
          };
        };

      # NixOS tests
      #
      # See nixpkgs/nixos/tests/bittorrent.nix for a more elaborate test.
      checks.x86_64-linux.default = pkgs.nixosTest {
        name = "Test for Hello module";

        nodes.machine = { ... }: {
          imports = [
            self.modules.default
          ];

          services.hello.enable = true;
        };

        testScript = ''
          start_all()

          # Check whether our service comes up.
          machine.wait_for_unit("hello");
        '';
      };

      # NixOS Overlay
      checks.x86_64-linux.patched-openssl = pkgs.nixosTest {
        name = "Test whether modified kernel boots";

        nodes.machine = { lib, ... }: {

          # Patch OpenSSL system-wide.
          nixpkgs.overlays = [
            (final: prev: {
              openssl = prev.openssl.overrideAttrs (old: {
                patches = old.patches ++ [
                  (pkgs.fetchpatch {
                    name = "improve-aes-xts-perf.patch";
                    url = "https://github.com/openssl/openssl/commit/858dfdfc67ea50fbe9ba38250daf306d5d0370a3.patch";
                    hash = "sha256-bXEBiaS4EoeRTX+2yZ1CS/NzGHHIe4SFXGVaa6KL38E=";
                  })
                ];
              });
            })
          ];
        };

        testScript = ''
          start_all()

          # Wait until everything comes up.
          machine.wait_for_unit("multi-user.target")
        '';
      };

      # NixOS Kernel Customization
      checks.x86_64-linux.custom-kernel = pkgs.nixosTest {
        name = "Test whether modified kernel boots";

        nodes.machine = { lib, pkgs, ... }: {

          boot.kernelPackages = pkgs.linuxPackages_latest;

          boot.kernelPatches = [
            {
              name = "Enable hardening";

              # We could apply patches here as well.
              #
              patch = null;

              extraStructuredConfig = {
                # Secure, but has performance impact.
                INIT_ON_ALLOC_DEFAULT_ON = lib.kernel.yes;
                INIT_ON_FREE_DEFAULT_ON = lib.kernel.yes;
              };
            }
          ];
        };

        testScript = ''
          start_all()

          # Wait until everything comes up.
          machine.wait_for_unit("multi-user.target")
        '';
      };

      # NixOS images
      #
      # See sysupdate-playground.
    };
}
