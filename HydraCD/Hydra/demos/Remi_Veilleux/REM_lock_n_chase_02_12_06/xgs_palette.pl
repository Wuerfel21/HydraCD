use integer;

print "Export a palette-set. Input a 4x64 BMP in 24-bit named palette.BMP.\n";
print "  Also requires 'hydra_color.BMP 87x1 24-bit reference image.\n";

open INPUT, "hydra_color.bmp";
binmode INPUT;
read INPUT, $_, 0x36;

my $palette = "";

# Read the whole BMP in a string.
for($i=0; $i<87; $i++)
{
	read INPUT, $_, 3;
	my ($b,$g,$r) = unpack "CCC", $_;

	$palette .= chr($r).chr($g).chr($b);
}
close INPUT;

my $hydra_color = "";
my $temp;
for($j=0; $j<5; $j++)
{
	for($i=0; $i<16; $i++)
	{
		if($i < 10)
		{
			$temp = chr($i + 48);
		}
		else
		{
			$temp = chr($i + 65 - 10);
		}
		$temp .= chr($j + 65);
		$hydra_color .= $temp;
	}
}
$hydra_color .= "020304050607";

# print $hydra_color;

open INPUT, "palette.bmp";
binmode INPUT;
read INPUT, $_, 0x36;

my $font = "";

# Read the whole BMP in a string.
for($j=0; $j<64; $j++)
{
	for($i=0; $i<4; $i++)
	{
		read INPUT, $_, 3;
		my ($b,$g,$r) = unpack "CCC", $_;

		$font .= chr($r).chr($g).chr($b);
	}
}
close INPUT;

# Flip it (because BMP are stored bottom-up)
for($j=0; $j<64/2; $j++)
{
	$temp = substr($font, $j*4*3, 4*3);
	substr($font, $j*4*3, 4*3) = substr($font, (63-$j)*4*3, 4*3);
	substr($font, (63-$j)*4*3, 4*3) = $temp;
}

# Look up to n 4-color palette
for($j=0; $j<10; $j++)
{
	printf "palette%02i               byte ", $j;
	my $temp_number = 0;
	for($i=0; $i<4; $i++)
	{
		my $basepos = ($i+($j)*4)*3;

		my $r = ord(substr($font, $basepos, 1));
		my $g = ord(substr($font, $basepos+1, 1));
		my $b = ord(substr($font, $basepos+2, 1));

		# find closest color from our hydra reference set
		my $best_diff = 999999999;
		my $best_index = 0;
		for($c=0; $c<87; $c++)
		{
			my $r2 = ord(substr($palette, $c*3, 1));
			my $g2 = ord(substr($palette, $c*3+1, 1));
			my $b2 = ord(substr($palette, $c*3+2, 1));
			
			my $diff = ($r2-$r)*($r2-$r) + ($g2-$g)*($g2-$g) + ($b2-$b)*($b2-$b);
			if($diff < $best_diff)
			{
				$best_diff = $diff;
				$best_index = $c;
			}
		}
		#print "Closest of $r,$g,$b is entry \$", substr($hydra_color, $best_index*2, 2), "\n";
		print "\$", substr($hydra_color, $best_index*2, 2);
		if($i < 3)
		{
			print ",";
		}
	}	

	printf "\n";
}	
