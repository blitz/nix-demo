# Welcome to the Nix/Nixpkgs/NixOS demo!
#
# This is not meant as a tutorial. We are going through usage examples
# to see what you can do with Nix.
#
# Good resources to start out with Nix are:
# - https://zero-to-nix.com/
# - https://nix.dev/
# - https://nixos.org/guides/nix-pills/
#
# Reference documentation:
# - https://nixos.org/learn/
#
# Ok. Let's go!
#
# ----------------------------------------------------------------------------
#
# This file is written in the Nix language. Nix is "JSON with
# functions". The Nix language is used to describe how software is
# built ("derivations").
#
# This file is a Nix "Flake", a self-contained description of
# software. Everyone building this gets the same output.
{
  description = "A set of Nix/NixOS capability demos";

  inputs = {
    # Nixpkgs is a collection of packages ("derivations") written in Nix.
    #
    # How many packages are there: https://repology.org/repositories/graphs
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    # We use lock files to pin our dependencies.
  };

  # --------------------------------------------------------------------------

  outputs = { self, nixpkgs }:
    let
      # The native x86_64-linux environment.
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      # Library functions.
      lib = nixpkgs.lib;

      # Special-purpose environments.
      aarch64Pkgs = pkgs.pkgsCross.aarch64-multiplatform;
      riscvPkgs = pkgs.pkgsCross.riscv64;
      staticPkgs = pkgs.pkgsStatic;

      # A useful shorthand for later.
      selfPkgs = self.packages.x86_64-linux;
    in
    {
      ### The simplest derivation
      #
      # This is not useful in practice, but shows some concepts:
      #
      # - Derivations
      # - Build Process
      # - Nix store
      packages.x86_64-linux.simple = builtins.derivation {
        name = "simple";
        builder = "/bin/sh";
        args = [ "-c" "echo Rebuilding. ; echo 10 > $out" ];
        system = "x86_64-linux";
      };

      ### Basic packaging of a C application.
      #
      # See: hello/default.nix
      #
      # Interesting points to checkout:
      # - the derivation: nix show derivation
      # - the Nix daemon
      # - the sandbox
      # - the build cache
      # - the Nix store
      packages.x86_64-linux.hello = pkgs.callPackage ./hello { };

      # Maybe we want a static binary.
      packages.x86_64-linux.helloStatic = staticPkgs.callPackage ./hello { };

      # Package your build and development environment with shell
      # environments.
      devShells.x86_64-linux.default = pkgs.mkShell {
        # Get all tools to build the software.
        inputsFrom = [ selfPkgs.hello ];

        # Common developer tools.
        packages = [
          pkgs.qemu-user
          pkgs.clang-tools
        ];
      };

      # You can use the developer shell with `nix develop` or direnv.

      # Sometimes you need to build software with different
      # dependencies or features.
      packages.x86_64-linux.helloClang = selfPkgs.hello.override {
        # Build with clang.
        stdenv = pkgs.clangStdenv;

        # Use a different OpenSSL version.
        openssl = pkgs.openssl_3_3;
      };

      # We can massage everything from nixpkgs as well.
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

      ### Packaging Rust
      packages.x86_64-linux.helloRust = pkgs.callPackage ./hello-rust { };
      packages.x86_64-linux.helloRustStatic = staticPkgs.callPackage ./hello-rust { };

      ### Packaging Python
      packages.x86_64-linux.helloPython = pkgs.python313Packages.callPackage ./python { };

      # We can use different Python versions as well.
      packages.x86_64-linux.helloPython39 = pkgs.python39Packages.callPackage selfPkgs.helloPython.override { };
      # What about quick'n'dirty shell scripts?
      #
      # The different Python versions coexist without problems.
      packages.x86_64-linux.twoPythons = pkgs.writeShellScriptBin "two-pythons" ''
        ${lib.getExe selfPkgs.helloPython}
        ${lib.getExe selfPkgs.helloPython39}
      '';

      ### For more languages, check:
      #
      # https://nixos.org/manual/nixpkgs/stable/#chap-language-support

      ### Let's build NixOS systems!
      #
      # Let's move on to building NixOS systems. The main building
      # blocks are NixOS modules.
      #
      # See: https://nixos.org/manual/nixos/stable/#sec-configuration-syntax
      #
      # Real example: https://github.com/blitz/nix-configs/blob/master/modules/work-dhcp.nix
      # Options search: https://search.nixos.org/options
      #
      # Here is a minimal example.
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

      ### NixOS tests
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

      # Tests can be interactively debugged:
      # nix -L build .#checks.x86_64-linux.default.driverInteractive

      ### Patching software everywhere
      #
      # To patch software globally in a NixOS system, we use overlays.
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

      # For example for embedded systems, it's useful to tweak and
      # patch the Linux kernel.
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

          # Check whether the config was applied.
          machine.succeed("zgrep -q /proc/config.gz CONFIG_INIT_ON_ALLOC_DEFAULT_ON=y")
          machine.succeed("zgrep -q /proc/config.gz CONFIG_INIT_ON_FREE_DEFAULT_ON=y")
        '';
      };

      # We can introspect NixOS configurations without building everything.
      #
      # nix -L build .#checks.x86_64-linux.custom-kernel.config.nodes.machine.boot.kernelPackages.kernel.configfile

      # There is a lot of tooling to build immutable and image-based systems.
      #
      # See: https://github.com/blitz/sysupdate-playground

      # There are convenient options to build CIs.
      #
      # See: https://hercules-ci.com/github/blitz/nix-demo

      # We can build Linux kernel live patches.
      #
      # See: https://github.com/blitz/kvm-livepatch
    };
}
