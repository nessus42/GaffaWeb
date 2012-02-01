

$WEBGLIMPSE_HOME = "/usr2/local/glimpsehttp3";

# name of config file
$CONFIGFILE = "archive.cfg";


########################################################################
sub SaveConfig	{
	my($archivepwd,@thearray)=@_;
	my($outstring);
	local(*CFG);

	eval{
		open(CFG, ">$archivepwd/$CONFIGFILE");
	};
	if($@){
		return 0;
	}else{
		$outstring = join("\t",@thearray);
		print CFG $outstring;
		close CFG;
		return 1;
	}
}

########################################################################
sub ReadConfig{
	my($indexdir) = @_;
	my(@input);
	local(*CFG);

	eval{
		open(CFG, "$indexdir/$CONFIGFILE");
	};
	if($@){
		return undef;
	}else{
		@input = <CFG>;
		close CFG;
		return split("\t", @input[0]);
	}
}

########################################################################
sub TestConfig{
	my($indexdir) = @_;

	if(-r "$indexdir/$CONFIGFILE"){
		return 2;
	}
	if(-e "$indexdir/$CONFIGFILE"){
		return 1;
	}
	return 0;
}

1;
