
use XML::DifferenceMarkup qw(merge_diff);

use strict;

our $testdata;

BEGIN {
    $testdata = [
		 {
		  name => 'same docs',
		  a => <<A_SAME_DOCS,
<?xml version="1.0"?>
<some>
  <tree/>
</some>
A_SAME_DOCS
		  b => <<B_SAME_DOCS,
<?xml version="1.0"?>
<some>
  <tree/>
</some>
B_SAME_DOCS
		  diff => <<DIFF_SAME_DOCS
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <dm:copy count="1"/>
</dm:diff>
DIFF_SAME_DOCS
		 },
		 {
		  name => 'different attributes',
		  a => <<A_DIFFERENT_ATTRIBUTES,
<?xml version="1.0"?>
<node with="attr"/>
A_DIFFERENT_ATTRIBUTES
		  b => <<B_DIFFERENT_ATTRIBUTES,
<?xml version="1.0"?>
<node with="other value"/>
B_DIFFERENT_ATTRIBUTES
		  diff => <<DIFF_DIFFERENT_ATTRIBUTES
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <dm:delete>
    <node with="attr"/>
  </dm:delete>
  <dm:insert>
    <node with="other value"/>
  </dm:insert>
</dm:diff>
DIFF_DIFFERENT_ATTRIBUTES
		 }
		];
}

use Test::More tests => scalar @$testdata;

my $parser = XML::LibXML->new();
$parser->keep_blanks(0);

foreach my $data (@$testdata) {
    my $a = $parser->parse_string($data->{a});
    my $diff = $parser->parse_string($data->{diff});
    my $merge = merge_diff($a, $diff);
    is($merge->toString(1), $data->{b}, $data->{name});
}

