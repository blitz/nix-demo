{
  description = "A set of Nix/NixOS capability demos";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    # Demo: Lock files
  };

  outputs = { self, nixpkgs }:
    let
      # The native x86_64-linux environment.
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      # Cross-compilation environments.
      aarch64Pkgs = pkgs.pkgsCross.aarch64-multiplatform;
      riscvPkgs = pkgs.pkgsCross.riscv64;

      # A useful shorthand for later.
      selfPkgs = self.packages.x86_64-linux;
    in
    {

      # Basic packaging
      packages.x86_64-linux.hello = pkgs.callPackage ./hello { };

      # Cross-compilation
      packages.aarch64-linux.hello = aarch64Pkgs.callPackage ./hello { };
      packages.riscv64-linux.hello = riscvPkgs.callPackage ./hello { };

      # Cross-compiling works for (almost) everything in nixpkgs.
      packages.riscv64-linux.openssl = riscvPkgs.openssl;

      # Shell environments
      devShells.x86_64-linux.default = pkgs.mkShell {

        # Get a cross-compilation environment.
        inputsFrom = [ self.packages.riscv64-linux.hello ];

        # Get the tools to run the resulting binary.
        packages = [ pkgs.qemu-user ];
      };

      # Overrides
      packages.x86_64-linux.helloClang = selfPkgs.hello.override {
        # Build with clang.
        stdenv = pkgs.clangStdenv;

        # Use a different OpenSSL version.
        openssl = pkgs.openssl_3_3;
      };

      # Let's patch packages.
      packages.x86_64-linux.helloPatched = selfPkgs.hello.overrideAttrs {
        patches = [
          ./hello/example.patch
        ];
      };

      # We can also patch other software.
      packages.x86_64-linux.patchedOpenssl = pkgs.openssl.overrideAttrs (old: {
        patches = old.patches ++ [
          (pkgs.fetchpatch {
            name = "improve-aes-xts-perf.patch";
            url = "https://github.com/openssl/openssl/commit/858dfdfc67ea50fbe9ba38250daf306d5d0370a3.patch";
            hash = "sha256-bXEBiaS4EoeRTX+2yZ1CS/NzGHHIe4SFXGVaa6KL38E=";
          })
        ];
      });

      # And then use it as dependency.
      packages.x86_64-linux.helloPatchedOpenssl = selfPkgs.hello.override {
        openssl = selfPkgs.patchedOpenssl;
      };

      # NixOS modules
      #
      # Let's move on to building NixOS systems. The main building
      # blocks are NixOS modules.
      modules.default = { config, lib, ... }:
        with lib;
        let
          cfg = config.services.hello;
        in
        {
          # Define a set of configuration options for this module.
          options.services.hello = {
            enable = mkEnableOption "Hello Module";

            # Allow the user to config
            package = mkOption {
              type = types.package;
              default = selfPkgs.hello;
              description = "Set the package that should be used";
            };

            harden = mkEnableOption "hardening for the systemd service";
          };

          # This is the configuration fragment that this module adds
          # to a NixOS configuration.
          config = mkIf cfg.enable {
            # Deploy a systemd service.
            systemd.services.hello = {
              wantedBy = [ "multi-user.target" ];

              serviceConfig = {
                ExecStart = lib.getExe cfg.package;
                RemainAfterExit = true;
              };

              # Use config options to configure everything.
              confinement.enable = cfg.harden;
            };
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

      # Interactive debugging of tests
      #
      # nix -L build .#checks.x86_64-linux.default.driverInteractive

      # NixOS Overlay
      checks.x86_64-linux.patched-openssl = pkgs.nixosTest {
        name = "Test whether modified kernel boots";

        nodes.machine = { lib, ... }: {

          # Patch OpenSSL system-wide.
          nixpkgs.overlays = [
            (final: prev: {
              openssl = selfPkgs.patchedOpenssl;
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
      # See: https://github.com/blitz/sysupdate-playground

      # CI
      #
      # See: https://hercules-ci.com/github/blitz/nix-demo
    };
}
