use integer;

my $name = "floor";
my $filename = $name . ".bmp";
my $width;
my $height;

print "Export a tile-set. Input a BMP in 8-bit paletted named $filename.\n";
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

# UPDATE: Hydra_Color is now pre-subtracted by $02 in order to get black = 00
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
		
		my $c = $j + 8;
		if($c < 10)
		{
			$temp .= chr($c + 48);
		}
		else
		{
			$temp .= chr($c + 65 - 10);
		}
		$hydra_color .= $temp;
	}
}
$hydra_color .= "000102030405";

open INPUT, $filename;
binmode INPUT;
read INPUT, $_, 18;	# skip first 18 bytes of header
read INPUT, $_, 4; # width
$width = ord($_);
read INPUT, $_, 4; # height
$height = ord($_);
read INPUT, $_, 2; # skip 'planes'
read INPUT, $_, 2; # bpp
my $bpp = ord($_);
read INPUT, $_, 16; # skip crap

read INPUT, $_, 4; # color used
my $colorused = ord($_);
read INPUT, $_, 4; # color important??!
my $colorimportant = ord($_);

#print "width = $width h=$height bpp=$bpp colorused=$colorused colorimportant=$colorimportant\n";

my $colortable = "";

my $hydratranslate = "";

# reading color table
for($i=0; $i<$colorused; $i++)
{
	read INPUT, $_, 4;
	
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

for($j=0; $j<$height; $j++)
{
	if($j == 0)
	{
		printf "%s000 long ", $name;
	}
	elsif(($j & 1) == 0)
	{
		printf "        long ";
	}
	$temp = "";
	for($i=0; $i<$width; $i++)
	{
		# because of 'long', we must output $i backward: 3,2,1,0,7,6,5,4,...
		my $i2 = (3-($i & 3)) + ($i & ~3);

		my $basepos = ($i2+$x+($j+$y)*$width);

		my $p = ord(substr($image, $basepos, 1));

		if(($i & 3) == 0)
		{
			if(($j & 1) == 1 || $i != 0)
			{
				$temp .= ",";
			}
			$temp .= "\$";
		}
		$temp .= substr($hydratranslate, $p*2, 2);

		#printf("p=$p -> $temp\n");
	}
	if(($j & 1) == 1)
	{
		$temp .= "\n";
	}
	printf("$temp");
}
