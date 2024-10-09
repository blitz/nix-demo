project('hello', 'c', version : '0.1')

libopenssl = dependency('openssl')

executable('hello', 'hello.c',
           dependencies: [ libopenssl ],
           install: true)
