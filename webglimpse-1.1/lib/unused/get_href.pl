package get_href;

sub get_href	{
	local($file) = @_;
	local ($i, $link, $url);

	readFile($file);
	local(@links) = split(/<A[\s]+HREF[\s]*=[\s]*/i, $page);
	local(@lnks);
	foreach $i (1..$#links)	{
		$link = $links[$i];
		if ($link =~ m|^"?([^>"]*)"?|)	{
			$lnks[$i] = $1;
		}
	}
	return @lnks;
}

sub readFile	{
	local($file) = @_;

	open (F, $file);
	$page = "";
	while (<F>)	{
		$page .= $_;
	}
	close F;
}

1;
