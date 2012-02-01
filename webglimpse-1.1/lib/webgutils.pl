##############################################
# utility routines
##############################################


$webgutils="1";

##########################################################################
sub read_bool {
	local($prompt,$def) = @_;

	if($def==1){
		$def = "y";
	}elsif($def==0){
		$def = "n";
	}
	$ans = -1;
	until($ans >= 0){
		print $prompt,"[",$def,"] (y/n):";
		$| = 1;
		$_ = <STDIN>;
		chomp;
		$_ = $_ ? $_ : $def;
		$_ = substr($_, 0, 1);
		if ($_ eq "y" || $_ eq "Y"){
			$ans = 1;
		}elsif ($_ eq "n" || $_ eq "N"){
			$ans = 0;
		}else {
			print "Please enter y or n.\n";
		}
	}
	return $ans;
}

##########################################################################
sub prompt {
	local($prompt,$def) = @_;
	print $prompt,"[",$def,"]:";
	$| = 1;
	$_ = <STDIN>;
	chomp;
	return $_?$_:$def;
}

##########################################################################
sub getcorefilelist{
	local($dir) = @_;
	local(@files, @subdirs, @sublist, $file, @corefilelist);
	@subdirs=();
	@files=();

	# read the directory for html files
	opendir(DIR, $dir) || die "Unable to open directory $dir: ";

	file: while ($file=readdir(DIR)) {
		# skip the file if it starts with a '.' or is one of OUR config files
		next if $file =~ /^\./;
		next if $file eq $HTMLINDEX;

		# if dir, put it in dirlist
		if(-d $file){
			push(@subdirs, $file);
		}else{
			# skip if not a core file
			next if $file !~ /$COREFILES/;

			# add it to file list
			push(@corefilelist, "$dir/$file");
		}
	}
	closedir(DIR);

	# traverse all subdirs, and get the file from there
	foreach $file(@subdirs){
		&getcorefilelist("$dir/$file");
	}

	### TO DO -- intersect with .glimpse_exclude
}
1;
