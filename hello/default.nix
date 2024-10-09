{ stdenv, meson, ninja, openssl, pkg-config }:
stdenv.mkDerivation {
  pname = "hello";
  version = "1.0";

  # Typically, we would fetch a release tarball here.
  src = ./src;

  # Packages needed on the host system.
  nativeBuildInputs = [
    meson
    ninja
    pkg-config
  ];

  # Packages needed on the target system.
  buildInputs = [
    openssl
  ];

  meta = {
    # Add licenses, maintainers, description, ...
    mainProgram = "hello";
  };
}
