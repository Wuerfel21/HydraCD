use integer;

my $name = "remmap";
my $filename = $name . ".txt";

print "Convert a MAPPY exported map. Input a TXT named $filename.\n";

open(INPUT, $filename);
@raw_data = <INPUT>;

my $count = 0;

foreach $t (@raw_data)
{
	# Skip first 'const' line and all line starting with a ','
	$first = substr($t, 0, 1);
	if($first eq "c" || $first eq "," || $first eq "}")
	{
		next;
	}
	
	$t = substr($t, 0, -1);	# remove cr/lf
	$last = substr($t, -1); 
	if($last eq " ")
	{
		$t = substr($t, 0, -2);
	}
	if($last eq ",")
	{
		$t = substr($t, 0, -1);
	}
	if(length($t) == 0)
	{
		last;
	}
	#print "read [$t]\n";
	printf "tilemap%03i   byte $t\n", $count;

	$count++;
}


close INPUT;
