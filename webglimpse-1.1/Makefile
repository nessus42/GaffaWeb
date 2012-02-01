# httpget uses httpget.c and utils.h in the lib directory
# html2txt is a very simple text-parsing program to strip HTML tags

# It has been compiled on the following platforms
#  sunos solaris osf
# I am not able to port it and test it on every platform.

# This will get called from the wginstall script.
# Sunos uses gcc
# Solaris requires specifying the nsl and socket libaries
# OSF uses cc
# 'another-config' uses gcc and the libraries

# If your OS isn't supported, try compiling (using make) for each
# option; if it compiles cleanly for one of the supported options,
# httpget should work just fine (you can test it from the command line).

# Good luck!



CC = gcc

sunos:
	$(CC) -O -o lib/httpget lib/httpget.c
	$(CC) -O -o lib/html2txt lib/html2txt.c

solaris:
	$(CC) -O -o lib/httpget lib/httpget.c -lnsl -lsocket
	$(CC) -O -o lib/html2txt lib/html2txt.c

osf:
	$(CC) -O -o lib/httpget lib/httpget.c
	$(CC) -O -o lib/html2txt lib/html2txt.c

another-config:
	$(CC) -O -o lib/httpget lib/httpget.c -lnsl -lsocket
	$(CC) -O -o lib/html2txt lib/html2txt.c
