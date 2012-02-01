

# name of config file
$CONFIGFILE = "archive.cfg";


# valid configuration variables
@ConfigVars = qw(
		 title
		 urlpath
		 traverse_type
		 explicit_only
		 numhops
		 nhhops
		 local_limit
		 remote_limit
		 addboxes
		 urllist
);  # in *that* order


# eg.
#  ($title, $urlpath, $traverse_type, $explicit_only, $numhops,
#   $nhhops, $local_limit, $remote_limit, $addboxes, @urllist) = ReadConfig;
#  SaveConfig ($title, $urlpath, $traverse_type, $explicit_only, $numhops,
#              $nhhops, $local_limit, $remote_limit, $addboxes, @urllist);


########################################################################
sub RawReadConfig {
   my($indexdir) = @_;
   local(*CFG);
   my(@input);

   eval{
      open(CFG, "$indexdir/$CONFIGFILE");
   };
   if($@){
      return undef;
   } else {
      # read the input
      @input = <CFG>;
      close CFG;
   }
   return @input;
}

########################################################################
sub ReadConfig {
   my($indexdir) = @_;
   my(@input, @lines, $line);
   my(%Values);

   @input = RawReadConfig($indexdir);
   if($input eq 0) {
      return undef;
   }

   # remove all commented lines
   @lines = grep !/^\s*\#/, @input;
   
   my($var);

   # fill in the values so there's *something* there...
   foreach $var (@ConfigVars) {
      $Values{$var} = "{}";
   }

   foreach $line (@lines) {
      chomp($line);

      my($okay) = 0;
      foreach $var (@ConfigVars) {
	 if($line =~ /^\s*$var\s*(.*)/i){
	    # if it's not urllist, just assign
	    $Values{$var} = $1;
	    $okay = 1;
	    last;
	 }
      }
      if(!$okay){
	 print "Error in configuration file.\n line: $line\n";
      }
   }

   my(@retlist);
   foreach $var (@ConfigVars) {
      if($var ne "urllist"){
	 push(@retlist, $Values{$var});
      }
   }
   return (@retlist, split(/\s+/, $Values{urllist}));
}


########################################################################
sub SaveConfig {
   my($archivepwd,$toplines,@thearray)=@_;
   local(*CFG);
   my(%Values, @urllist, %ValuesSet);

   my($setstring) = "( ";
   foreach $var (@ConfigVars) {
      if($var ne "urllist"){
	 $setstring .= " \$Values{$var}, ";
      }else {
	 $setstring .= " \@$var ";
      }
   }

   $setstring .= ") = \@thearray;";
   eval $setstring;

   $Values{urllist} = join(" ", @urllist);

   @config = RawReadConfig($archivepwd);

   my($line, $var);
   # substitute the values if they're already there
   foreach $line (@config) {
      foreach $var (@ConfigVars) {
	 if ($line =~ /^\s*$var\s+/) {
	    $line = "$var $Values{$var}\n";
	    $ValuesSet{$var} =1;
	 }
      }
   }

   # now write out the values that aren't there yet
   foreach $var (@ConfigVars) {
      if(!$ValuesSet{$var}){
	 push(@config, "$var $Values{$var}\n"); 
      }
   }

   eval{
      open(CFG, ">$archivepwd/$CONFIGFILE");
   };
   if($@){
      return 0;
   }else{
		print CFG "$toplines\n";
      print CFG @config;
      close CFG;
      return 1;
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


########################################################################
sub OldSaveConfig	{
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
sub OldReadConfig{
   my($indexdir) = @_;
   my(@input);
   local(*CFG);
   
   eval{
      open(CFG, "$indexdir/$CONFIGFILE");
   };
   if($@){
      return undef;
   } else {
      # read the input
      @input = <CFG>;
      close CFG;

      # remove all commented lines
      
      return split("\t", @input[0]);
   }
}




1;
