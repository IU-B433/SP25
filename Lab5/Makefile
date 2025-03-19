CC=gcc
# no warnings for implicit function declaration
CFLAGS=-fno-stack-protector -m32 -Wno-implicit-function-declaration -Wno-deprecated-declarations

all: buf1 buf2 buf3

%: %.c
	$(CC) $(CFLAGS) $< -o $@

clean:
	rm -f buf1 buf2 buf3