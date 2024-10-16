{
  buildPythonApplication
, setuptools
, setuptools-scm
}:

buildPythonApplication {
  pname = "hello-world";
  version = "0.1.0";

  pyproject = true;

  src = ./hello_world;

  build-system = [
    setuptools
    setuptools-scm
  ];

  dependencies = [
    setuptools
  ];

  meta = {
    mainProgram = "hello-world";
  };
}
