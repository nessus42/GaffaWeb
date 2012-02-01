require "URL.pl";

$WEBGLIMPSE_HOME = "/usr2/mdsmith/pkg/webglimpse";

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

$URL_ERROR=0;
$URL_LOCAL=1;
$URL_REMOTE=2;
$URL_SCRIPT=3;

########################################################################
sub siteconf_ReadConf	{
	local(@thearray);

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
	local($name,$aliases,$dm3,$dm4,$addrs) = gethostbyname($Server);
	local($alias);
	$ServerCache{$Server} = $addrs;
	$ServerCache{$name} = $addrs;
	foreach $alias (@aliases)	{
		$ServerCache{$alias} = $addrs;
	}
	$ServerAddress = $addrs;
}

########################################################################
sub siteconf_CheckUrl	{
	local($url) = @_;
	local($alias);

	local($protocol,$host,$port,$path) = &url'parse_url($url);
	### TO DO -- error checking -- check for parsing problem
	# if ($protocol==undef)	{
		# print ERRLOG "Error parsing $url\n";
		# print "ERROR\n";
		# return $URL_ERROR;
	# }

	if ($port != $Port)	{
		return $URL_REMOTE;
	}

	if ($host eq $Server)	{
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
		local($name,$aliases,$addr,$len,$addrs) = gethostbyname($host);
		if ($name eq "")	{
		#	Cannot locate the server!
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

	if ($addrs eq $ServerAddress && $port == $Port)	{
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

sub siteconf_LocalUrl2File	{
	local($url) = @_;
	local($alias, $homedir, $retstring);

	$retstring="";
	local($protocol,$host,$port,$path) = &url'parse_url($url);
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

sub siteconf_LocalFile2Url	{
	local($file) = @_;
	local($alias, $homedir, $url);

	if ($Port eq "80")	{
		$portPart = "";
	} else	{
		$portPart = ":$Port";
	}

	if ($file =~ /^$DocumentRoot(.*)/)	{
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

sub siteconf_SaveCache	{
	open (FCACHE, ">$WEBGLIMPSE_HOME/.sitecache");
	foreach $host (keys %ServerCache)	{
		local($a, $b, $c, $d) = unpack('C4', $ServerCache{$host});
		print FCACHE "$host $a $b $c $d\n";
#		print "$host $a $b $c $d\n";
	}
	close FCACHE;
}

sub siteconf_LoadCache	{
	open (FCACHE, "$WEBGLIMPSE_HOME/.sitecache");
	while (<FCACHE>)	{
		local($host, $a, $b, $c, $d) = split(' ');
		$ServerCache{$host} = pack('C4', $a, $b, $c, $d);
	}
	close FCACHE;
}

1;
