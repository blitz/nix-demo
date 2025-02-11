# Check the manual for more information about Rust packaging:
# https://nixos.org/manual/nixpkgs/stable/#rust
{ lib, fetchFromGitHub, rustPlatform }:

rustPlatform.buildRustPackage {
  pname = "clac";
  version = "0-git";

  src = fetchFromGitHub {
    owner = "blitz";
    repo = "clac";
    rev = "0e695b7155cc3719178a7c29e95747afe75c2842";
    hash = "sha256-S1GMXIL4x1mGRzN3G9xuAhf+stsioROc8RidamaEtjI=";
  };

  cargoHash = "sha256-cObQtyh6/uLnXDv7CoWfZyfNa5c3RpVd5znba7vLlwU=";

  meta = {
    description = "A reverse polish command line calculator";
    homepage = "https://github.com/blitz/clac";
    license = lib.licenses.gpl3;
    maintainers = [ lib.maintainers.blitz ];
  };
}
