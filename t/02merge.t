
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
		 },
		 # 28Sep2002: not in the roundup tests because LibXML
		 # doesn't format the reconstructed b-document
		 # properly
		 {
		  name => 'two inserts',
		  a => <<A_TWO_INSERTS,
<?xml version="1.0"?>
<framework>
<structure/>
</framework>
A_TWO_INSERTS
		  b => <<B_TWO_INSERTS,
<?xml version="1.0"?>
<framework><structure>
with some
</structure>
inserted content...
</framework>
B_TWO_INSERTS
		  diff => <<DIFF_TWO_INSERTS
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <framework>
    <structure>
      <dm:insert xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
with some
</dm:insert>
    </structure>
    <dm:insert xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
inserted content...
</dm:insert>
  </framework>
</dm:diff>
DIFF_TWO_INSERTS
		 },
		 {
		  name => 'deep inserts',
		  a => <<A_DEEP_INSERTS,
<?xml version="1.0"?>
<framework>
<with>
<a>
<structure/>
</a>
</with>
</framework>
A_DEEP_INSERTS
		  b => <<B_DEEP_INSERTS,
<?xml version="1.0"?>
<framework><with><a><structure>
with some
</structure></a></with>
inserted content...
</framework>
B_DEEP_INSERTS
		  diff => <<DIFF_DEEP_INSERTS,
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <framework>
    <with>
      <a>
        <structure>
          <dm:insert>
with some
</dm:insert>
        </structure>
      </a>
    </with>
    <dm:insert>
inserted content...
</dm:insert>
  </framework>
</dm:diff>
DIFF_DEEP_INSERTS
		 },
		 {
		  name => 'spaced inserts',
		  a => <<A_SPACED_INSERTS,
<?xml version="1.0"?>
<framework>
<x1/>
<x2/>
<x3/>
<with>
<a>
<structure/>
</a>
</with>
<x4/>
<x5/>
</framework>
A_SPACED_INSERTS
		  b => <<B_SPACED_INSERTS,
<?xml version="1.0"?>
<framework><x1/><x2/><x3/><with><a><structure>
with some
</structure></a></with><x4/>
inserted content...
<x5/></framework>
B_SPACED_INSERTS
		  diff => <<DIFF_SPACED_INSERTS,
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <framework>
    <dm:copy count="3"/>
    <with>
      <a>
        <structure>
          <dm:insert>
with some
</dm:insert>
        </structure>
      </a>
    </with>
    <dm:copy count="1"/>
    <dm:insert>
inserted content...
</dm:insert>
    <dm:copy count="1"/>
  </framework>
</dm:diff>
DIFF_SPACED_INSERTS
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

