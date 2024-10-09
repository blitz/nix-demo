#include <stdio.h>
#include <stdlib.h>
#include <sys/utsname.h>
#include <openssl/opensslv.h>

int main()
{
  struct utsname utsname;
  int rc;

  rc = uname(&utsname);

  if (rc < 0) {
    perror("utsname");
    return EXIT_FAILURE;
  }
  
  printf("Hello from %s with OpenSSL version %s and %s %s.\n",
	 utsname.machine,
	 OPENSSL_VERSION_TEXT,
#ifdef __clang__
	 "Clang",
#elif __GNUC__
	 "GCC",
#else
	 "???",
#endif
	 __VERSION__);

  return EXIT_SUCCESS;
}
