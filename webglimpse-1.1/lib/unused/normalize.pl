#!/usr/local/bin/perl5


#############################################################
# Modified by Dachuan Zhang, May 23, 1996.
#	Take baseport into account!
#############################################################

package normalize;


require "URL.pl";

sub normalize{
	local($baseurl)=@_;
	
	($baseprot, $basehost, $baseport, $basepath) = &url'parse_url($baseurl);

	# get the name for the $basehost
	# ($name, $aliases, $addrtype,$length,@addrs) = gethostbyname($basehost);
	# ($a,$b,$c,$d) = unpack('C4', $addrs[0]);

	# separate basepath into basepath and basefile
	# find the LAST /
	$basefile = $basepath;
	$basepath =~ s/\/[^\/]*$//;
	$basepath .= "/"; # add the last / for the directory

	# output
	# print "baseprot = $baseprot, ";
	# print "basehost = $basehost\n ";
	# print "baseport = $baseport, ";
	# print "basepath = $basepath, ";
	# print "basefile = $basefile\n";

	shift(@_);		# remove $baseurl
	foreach $url(@_){
		# print "Original url: $url\n";
		# punt on the mailtos...
		if($url=~/^mailto:/i) {
			next;
		}

		# add things that might be missing.
		# if it starts with //
		if($url=~/^\/\//){
			# tack on http:
			$url = "http:".$url;
		}
		# if it has no :// it has no protocol
		if ($url=~/^:\/\//){
			# tack on http
			$url = "http".$url;
		}
	
		# if no protocol,
		if($url!~/^http:/i &&
			$url!~/^ftp:/i &&
			$url!~/^gopher:/i &&
			$url!~/^news:/i){
		
			# if no / at beginning, it's relative, on same machine, same path
			if($url!~/^\//){
				$url = $baseprot."://".$basehost.":".$baseport.$basepath.$url;
			}else{	# there is a / at the beginning
				# it's a new path, same machine
				$url = $baseprot."://".$basehost.":".$baseport.$url;
			}
		}
		# print "URL before parsing: $url\n";

		($prot, $host, $port, $path) = &url'parse_url($url);
		# print "URL after parsing: $prot://$host:$port$path\n";

		# make sure the path has a preceding /
		$path = "/$path" if $path!~/^\//;

		# remove "/A/.." from "/A/../dir"
		$path =~ s/\/[^\/]+\/\.\.//g;

		# Uncomment for numbers
		# if($host!~/\d+\.\d+\.\d+\.\d+/){
			# ($name, $aliases, $addrtype,$length,@addrs) = gethostbyname($host);
			# ($a,$b,$c,$d) = unpack('C4', $addrs[0]);
 
			# set host to the IP addr to prevent name aliasing
			# $host = "$a.$b.$c.$d";
		# }

		$url = "$prot://$host:$port$path";
		# print "URL after: $url\n";

		# strip off any #text
		$url =~ s/#.+$//;

		# also, for consistency in our database, NO trailing /'s
		# NO!  This causes a problem with the ROOT
		# $url =~ s/\/$//;
		
	}
		
	return;

}
1;
