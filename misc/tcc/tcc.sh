#tcc -shared -rdynamic -g -o test_lib.so -I. -I/usr/local/lib/ruby/1.8/i686-linux/ test_lib.c

tcc -shared -rdynamic -g -o test_lib.so -I.  -I/usr/local/lib/ruby/1.8/i686-linux/ -L"/usr/local/lib" -ldl -lcrypt -lm -lc test_lib.c

#tcc -I. -I/usr/local/lib/ruby/1.8/i686-linux/ \
# /home/vjoel/ruby/src/ruby/libruby-1.8.0-static.a \
# -run test_lib.c

# -lruby-1.8.1-static 
