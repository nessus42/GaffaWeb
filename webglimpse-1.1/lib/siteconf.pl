require "URL.pl";

package siteconf;

$WEBGLIMPSE_HOME = "/usr2/bgopal/webglimpse/webglimpse";

$wgConfPath = "$WEBGLIMPSE_HOME/.wgsiteconf";
$prefix = "^DirectoryIndex|^UserDir|^Alias|^ScriptAlias|^DocumentRoot";

$DirectoryIndex="";
$UserDir="";
$DocumentRoot="";
@AliasList=();
@ScriptAliasList=();
@ServerCache=();
$Port="";
$Server="";
$ServerAddress="";
%HomeDir={};

$NUM_IP_ADDR_RE = '(\d+)\.(\d+)\.(\d+)\.(\d+)';

$URL_ERROR=0;
$URL_LOCAL=1;
$URL_REMOTE=2;
$URL_SCRIPT=3;

########################################################################
sub ReadConf	{
	my(@thearray);
	local(*WMCONF);

	open (WMCONF, "$wgConfPath") || die "Cannot read $wgConfPath.\n";

#	hmm, I am not sure if it's a bug. If you have 2 of
#	DirectoryIndex, UserDir or DocumentRoot, we use the last one.

	# load up the HomeDirArray
	while(@thearray = getpwent()){
		$HomeDir{@thearray[0]} = @thearray[7];
	}

	while (<WMCONF>)	{
		if (/^DirectoryIndex[\s]*([\S]*)/i)	{
			$DirectoryIndex = $1;
		} elsif (/^UserDir[\s]*([\S]*)$/i)	{
			$UserDir = $1;
		} elsif (/^DocumentRoot[\s]*([\S]*)$/i)	{
			$DocumentRoot = $1;
		} elsif (/^Alias[\s]*([\S]*)[\s]*([\S]*)$/i)	{
			push(@AliasList, $2);
		} elsif (/^ScriptAlias[\s]*([\S]*)[\s]*([\S]*)$/i)	{
			push(@ScriptAliasList, $2);
		} elsif (/^Port[\s]*([\S]*)$/i)	{
			$Port = $1;
		} elsif (/^Server[\s]*([\S]*)$/i)	{
			$Server = $1;
		}
	}
	if ($DirectoryIndex eq "")	{
		$DirectoryIndex = "index.html";
	}
	my($name,$aliases,$dm3,$dm4,$addrs) = gethostbyname($Server);
	my($alias);

	my(@aliaslist) = split(/\s+/,$aliases);

	### MDSMITH -- fix for server names
	# add the domain to the name
	my($domain) = $name;
	$domain =~ s/^[^\.]+//;
	### End fix

	$ServerCache{$Server} = $addrs;
	$ServerCache{$name} = $addrs;
	foreach $alias (@aliaslist)	{
		my($wholename) = "${alias}${domain}";

		### MDSMITH -- store both the local name and the whole name
		$ServerCache{$alias} = $addrs;
		$ServerCache{$wholename} = $addrs;
	}
	$ServerAddress = $addrs;
}

########################################################################
sub CheckUrl	{
	my($url) = @_;
	my($alias);

	my($protocol,$host,$port,$path) = &url'parse_url($url);
	### TO DO -- error checking -- check for parsing problem
	# if ($protocol==undef)	{
		# print ERRFILE "Error parsing $url\n";
		# print "ERROR\n";
		# return $URL_ERROR;
	# }

	if ($port != $Port)	{
		return $URL_REMOTE;
	}

	# if the host isn't just numbers and dots... check the names
	if ($host !~ /^$NUM_IP_ADDR_RE$/o){
		if ($host eq $Server)	{
			# print "Same server for url $url...\n";
			# check to make sure it's not a script
			foreach $alias (@ScriptAliasList){
				if($path =~ /^$alias(.*)/)   {
	#				print "SCRIPT.\n";
         				return $URL_SCRIPT;
				}
			}
			return $URL_LOCAL;
		}
	
		if ($ServerCache{$host} eq "")	{
			# print "Looking up host $host...\n";
			my($name,$aliases,$addr,$len,$addrs) = gethostbyname($host);
			# print " name: $name, aliases: $aliases\n";
			if ($name eq "")	{
			#	Cannot locate the server!
				print ERRFILE "Cannot find server $host.\n";
				return $URL_ERROR;
			} else	{
				$ServerCache{$name} = $addrs;
				$ServerCache{$host} = $addrs;
				foreach $alias (@aliases)	{
					$ServerCache{$alias} = $addrs;
				}
			}
		} else	{
			$addrs = $ServerCache{$host};
		}
	} else {
		# compute the addr from the name
		# $1, $2, etc. are in the NUM_IP_ADDR_RE
		$addrs = pack('C4', $1, $2, $3, $4);
		# print "Using packed address to determine host ip match...\n";
	}

	if ($addrs eq $ServerAddress && $port == $Port)	{
		# print "Same address for url $url as local...\n";
		# check to make sure it's not a script
		foreach $alias (@ScriptAliasList){
			if($path =~ /^$alias(.*)/)   {
#				print "SCRIPT.\n";
         			return $URL_SCRIPT;
			}
		}
		return $URL_LOCAL;
	}

	return $URL_REMOTE;
}

########################################################################
#	Assume we have one parameter url, and the argument should be in
#	http:// format, and local.

#  Assume only *local* files will be queried; we already know it's local

#	The result possibly will have substr like "//"

sub LocalUrl2File	{
	my($url) = @_;
	my($alias, $homedir, $retstring);

	$retstring="";
	my($protocol,$host,$port,$path) = &url'parse_url($url);
	if ($path =~ /\/$/)	{
		$path .= "$DirectoryIndex";
	}

	# check for home directory
	if($path =~ /^\/~([^\/]+)(.+)/){
		# find the home directory's *real* pwd
		# use getpwent structure, already created
		$homedir = $HomeDir{$1};
		chop ($homedir) if ($homedir=~/\/$/);  # remove any trailing /

		$retstring =  "$homedir/$UserDir$2";
	}else{
		# We want the longest match.
		foreach $alias (@AliasList)	{
			if ($path =~ /^$alias(.*)/)	{
				$path = $Alias{$alias}."/$1";
				$retstring =  $path;
			}
		}
	}

	# if no other one works; just return the obvious path
	$retstring =  $DocumentRoot.$path if ($retstring eq "");

	# if it's a directory, add /index.html
	if(-d $retstring){
		# append a / if needed
		$retstring = "$retstring/" if($retstring!~/\/$/);
		$retstring = $retstring.$DirectoryIndex;
	}

	return $retstring;
}

sub LocalFile2Url	{
	my($file) = @_;
	my($alias, $homedir, $url);

	if ($Port eq "80")	{
		$portPart = "";
	} else	{
		$portPart = ":$Port";
	}

	if ($file =~ /^$DocumentRoot(.*)/)	{
		#$url = "http://$Server$portPart$1"; --> someone suggested this change: should we do it?: bgopal
		$url = "http://$Server$portPart/$1";
		return $url;
	}

	#	We are NOT going for longest match.
	foreach $alias (keys %Alias)	{
		$homedir = $Alias{$alias};
		if ($file =~ /^$homedir(.*)$/)	{
			$url = "http://$Server$portPart$alias/$1";
			return $url;
		}
	}

	return "";
}

sub SaveCache	{
	open (FCACHE, ">$WEBGLIMPSE_HOME/.sitecache");
	foreach $host (keys %ServerCache)	{
		my($a, $b, $c, $d) = unpack('C4', $ServerCache{$host});
		print FCACHE "$host $a $b $c $d\n";
#		print "$host $a $b $c $d\n";
	}
	close FCACHE;
}

sub LoadCache	{
	open (FCACHE, "$WEBGLIMPSE_HOME/.sitecache");
	while (<FCACHE>)	{
		my($host, $a, $b, $c, $d) = split(' ');
		$ServerCache{$host} = pack('C4', $a, $b, $c, $d);
	}
	close FCACHE;
}

1;
