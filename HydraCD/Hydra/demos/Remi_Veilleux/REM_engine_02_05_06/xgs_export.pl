use integer;

my $width = 160;
my $height = 96;

print "Export a tile-set. Input a $width x $height BMP in 24-bit named buggy.BMP.\n";
print "  Also requires 'hydra_color.BMP 86x1 24-bit reference image.\n\n";

open INPUT, "hydra_color.bmp";
binmode INPUT;
read INPUT, $_, 54;

my $palette = "";

# Read the whole BMP in a string.
for($i=0; $i<86; $i++)
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

open INPUT, "parallax_ps.bmp";
binmode INPUT;
read INPUT, $_, 54;

my $colortable = "";

my $hydratranslate = "";

# reading color table (assume 86 color palette!)
for($i=0; $i<86; $i++)
{
	read INPUT, $_, 4;
	
	if($i < 86)
	{
		my ($b,$g,$r,$a) = unpack "CCCC", $_;

		#substr($colortable, ($i)*3, 3) = chr($r).chr($g).chr($b);
		my $currentrgb = chr($r).chr($g).chr($b);

		#printf("colortable i=$i r=$r g=$g b=$b\n");
		# look up in our reference color chart for this color
		my $found = -1;
		for($j=0; $j<86; $j++)
		{
			if(substr($palette, ($j)*3, 3) eq $currentrgb)
			{
				$found = $j;
				$j = 87;
			}
		}
		if($found == -1)
		{
			printf("Error: colortable entry i=$i r=$r g=$g b=$b was not found in reference chart\n");
		}
		
		$temp = substr($hydra_color, $found*2, 2);
		#printf("translation = $temp\n");
		$hydratranslate .= $temp;
	}
}

my $image = "";
# Read the whole BMP in a string.
for($j=0; $j<$height; $j++)
{
	for($i=0; $i<$width; $i++)
	{
		read INPUT, $_, 1;
		my ($p) = unpack "C", $_;
		
		substr($image, ($i+$j*$width), 1) = chr($p);
	}
}
close INPUT;

# Flip it (because BMP are stored bottom-up)
for($j=0; $j<$height/2; $j++)
{
	my $temp = substr($image, $j*$width, $width);
	substr($image, $j*$width, $width) = substr($image, ($height-1-$j)*$width, $width);
	substr($image, ($height-1-$j)*$width, $width) = $temp;
}

my $x = 0;
my $y = 0;

# Extract up to n tiles
for($c=0; $c<($width*$height/256); $c++)
{
	# Extract the first tile
	for($j=0; $j<16; $j++)
	{
		if($j == 0)
		{
			printf "tile%03i byte ", $c;
		}
		else
		{
			printf "        byte ";
		}
		$temp = "";
		for($i=0; $i<16; $i++)
		{
			my $basepos = ($i+$x+($j+$y)*$width);
			
			my $p = ord(substr($image, $basepos, 1));
			
			$temp .= "\$";
			$temp .= substr($hydratranslate, $p*2, 2);
			
			if($i < 15)
			{
				$temp .= ","
			}
			
			#printf("p=$p -> $temp\n");
		}
		printf("$temp\n");
	}
	
	$x += 16;
	if($x == $width)
	{
		$x = 0;
		$y += 16;
	}
}	
