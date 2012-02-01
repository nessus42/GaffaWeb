#!/usr/local/bin/./perl

$WEBGLIMPSE_HOME = "/usr2/bgopal/webglimpse/webglimpse";

# this just changes the args around, and calls url_get
$url = $ARGV[0];

#-o is argv[1]

$file = $ARGV[2];

system("$WEBGLIMPSE_HOME/lib/url_get -o $file $url");

