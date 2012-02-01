
# name of config file
$CONFIGFILE = "archive.cfg";


########################################################################
sub config_SaveConfig	{
	local($archivepwd,@thearray)=@_;
	local($outstring);

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
sub config_ReadConfig{
	local($indexdir) = @_;
	local(@input);

	eval{
		open(CFG, "$indexdir/$CONFIGFILE");
	};
	if($@){
		return undef;
	}else{
		### TO DO
		@input = <CFG>;
		close CFG;
		return split("\t", @input[0]);
	}
}

########################################################################
sub config_TestConfig{
	local($indexdir) = @_;

	if(-r "$indexdir/$CONFIGFILE"){
		return 2;
	}
	if(-e "$indexdir/$CONFIGFILE"){
		return 1;
	}
	return 0;
}
