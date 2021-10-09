use integer;

print "Export a tile-set. Input a 256x256 BMP in 24-bit named tiles.BMP.\n\n";
open INPUT, "tiles.bmp";
binmode INPUT;
read INPUT, $_, 0x36;

my $font = "";

# Read the whole BMP in a string.
for($j=0; $j<256; $j++)
{
	my @temp_line_array;
	
	for($i=0; $i<256; $i++)
	{
		read INPUT, $_, 3;
		my ($b,$g,$r) = unpack "CCC", $_;

		substr($font, ($i+$j*256)*3, 3) = chr($r).chr($g).chr($b);
	}
}
close INPUT;

# Flip it (because BMP are stored bottom-up)
for($j=0; $j<256/2; $j++)
{
	my $temp = substr($font, $j*256*3, 256*3);
	substr($font, $j*256*3, 256*3) = substr($font, (255-$j)*256*3, 256*3);
	substr($font, (255-$j)*256*3, 256*3) = $temp;
}

my $x = 0;
my $y = 0;

# Extract up to n tiles
for($c=0; $c<=53; $c++)
{
	# Extract the first tile
	printf "tile%03i                 long ", $c;
	for($j=0; $j<16; $j++)
	{
		my $temp_number = 0;
		for($i=0; $i<16; $i++)
		{
			my $basepos = ($i+$x+($j+$y)*256)*3;
			
			my $r = ord(substr($font, $basepos, 1));
			my $g = ord(substr($font, $basepos+1, 1));
			my $b = ord(substr($font, $basepos+2, 1));
			
			my $color = int(($r + $g + $b)/3) >> 6;
			
			$temp_number += ($color << (($i & 3) << 1)) << (($i >> 2) << 3);
		}	
		
		printf "\$%08x",$temp_number;
		if($j == 15)
		{
			printf "\n"
		}
		elsif($j == 7)
		{
			printf "\n                        long ";
		}
		else
		{
			printf ",";
		}	
	}
	
	$x += 16;
	if($x == 256)
	{
		$x = 0;
		$y += 16;
	}
}	
