#include <stdio.h>
#include <stdlib.h>
#include <sys/utsname.h>
#include <openssl/opensslv.h>
#include <openssl/crypto.h>

int main()
{
  struct utsname utsname;
  int rc;

  rc = uname(&utsname);

  if (rc < 0) {
    perror("utsname");
    return EXIT_FAILURE;
  }
  
  printf("Hello from %s with %s and %s %s.\n",
	 utsname.machine,
	 OpenSSL_version(OPENSSL_VERSION),
#ifdef __clang__
	 "", 			/* Not needed */
#elif __GNUC__
	 "GCC",
#else
	 "???",
#endif
	 __VERSION__);

  return EXIT_SUCCESS;
}
