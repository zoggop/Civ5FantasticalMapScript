my $screenfile = $ARGV[0];
my @parts = split(/\./, $screenfile);
my $name = $parts[0];
my $annotation = "";
foreach my $a (@ARGV) {
	if ($a ne $screenfile) {
		$annotation = $annotation . "\n" . $a;
	}
}
# my $command = "convert -size 1638x931 canvas:none -gravity center -font DejaVu-Sans -pointsize 32 -stroke #FFFF -strokewidth 6 -annotate 0 \"$annotation\" \( +clone -blur 0x25 \) -compose atop -composite $screenfile -stroke none -fill black -annotate 0 \"$annotation\" -quality 90 $name-annotated.jpg";
# \( +clone -blur 0x16 \)
system("convert $screenfile -brightness-contrast -100 -gravity center -font DejaVu-Sans -pointsize 32 -stroke #FFF9 -fill #0000 -strokewidth 8 -annotate 0 \"$annotation\" -blur 0x4 $name-blur.png");
system("composite -compose screen $name-blur.png $screenfile $name-below.png");
system("convert $name-below.png -gravity center -font DejaVu-Sans -pointsize 32 -annotate 0 \"$annotation\" -quality 90 $name-annotated.jpg");

system($command);