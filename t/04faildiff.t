
use XML::DifferenceMarkup qw(make_diff);

use strict;

our $testdata;

BEGIN {
    $testdata = [
		 {
		  name => 'reserved namespace',
		  a => <<A_SAME_DOCS,
<?xml version="1.0"?>
<some>
  <tree/>
</some>
A_SAME_DOCS
		  b => <<B_SAME_DOCS,
<?xml version="1.0"?>
<some>
  <x:tree xmlns:x="http://www.locus.cz/XML/DifferenceMarkup"/>
</some>
B_SAME_DOCS
		 }
		];
}

use Test::More tests => scalar @$testdata;

my $parser = XML::LibXML->new();
$parser->keep_blanks(0);

foreach my $data (@$testdata) {
    eval {
	make_diff($parser->parse_string($data->{a}),
		   $parser->parse_string($data->{b}));
    };
    like($@,
	 qr/^XML::DifferenceMarkup diff: /,
	 $data->{name});
}

