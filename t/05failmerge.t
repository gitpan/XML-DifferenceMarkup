
use XML::DifferenceMarkup qw(merge_diff);

use strict;

our $testdata;

BEGIN {
    $testdata = [
		 {
		  name => 'not a diff',
		  a => <<A_NOT_A_DIFF,
<?xml version="1.0"?>
<some>
  <tree/>
</some>
A_NOT_A_DIFF
		  diff => <<DIFF_NOT_A_DIFF
<?xml version="1.0"?>
<some>
  <tree/>
</some>
DIFF_NOT_A_DIFF
		 },
		 {
		  name => 'empty diff',
		  a => <<A_EMPTY_DIFF,
<?xml version="1.0"?>
<some>
  <tree/>
</some>
A_EMPTY_DIFF
		  diff => <<DIFF_EMPTY_DIFF
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup"/>
DIFF_EMPTY_DIFF
		 },
		 {
		  name => 'too many namespaces',
		  a => <<A_TOO_MANY_NAMESPACES,
<?xml version="1.0"?>
<some>
  <tree/>
</some>
A_TOO_MANY_NAMESPACES
		  diff => <<DIFF_TOO_MANY_NAMESPACES,
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup"
	xmlns:x="http://www.locus.cz/XML/DifferenceMarkup">
  <x:copy count="1"/>
</dm:diff>
DIFF_TOO_MANY_NAMESPACES
		 },
		 {
		  name => 'unknown instruction',
		  a => <<A_UNKNOWN_INSTRUCTION,
<?xml version="1.0"?>
<some>
  <tree/>
</some>
A_UNKNOWN_INSTRUCTION
		  diff => <<DIFF_UNKNOWN_INSTRUCTION
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <dm:changename from="some" to="other"/>
</dm:diff>
DIFF_UNKNOWN_INSTRUCTION
		 },
		 {
		  name => 'copy without count',
		  a => <<A_COPY_WITHOUT_COUNT,
<?xml version="1.0"?>
<some>
  <tree/>
</some>
A_COPY_WITHOUT_COUNT
		  diff => <<DIFF_COPY_WITHOUT_COUNT
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <dm:copy/>
</dm:diff>
DIFF_COPY_WITHOUT_COUNT
		 },
		 {
		  name => 'wrong name to delete',
		  a => <<A_WRONG_NAME_TO_DELETE,
<top>
<real/>
</top>
A_WRONG_NAME_TO_DELETE
		  diff => <<DIFF_WRONG_NAME_TO_DELETE
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <top>
    <dm:delete>
      <fake/>
    </dm:delete>
  </top>
</dm:diff>
DIFF_WRONG_NAME_TO_DELETE
		 },
		 {
		  name => 'extra name to delete',
		  a => <<A_EXTRA_NAME_TO_DELETE,
<top>
<real/>
</top>
A_EXTRA_NAME_TO_DELETE
		  diff => <<DIFF_EXTRA_NAME_TO_DELETE
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <top>
    <dm:delete>
      <real/>
      <real/>
      <real/>
    </dm:delete>
  </top>
</dm:diff>
DIFF_EXTRA_NAME_TO_DELETE
		 }
		];
}

use Test::More tests => scalar @$testdata;

my $parser = XML::LibXML->new();
$parser->keep_blanks(0);

foreach my $data (@$testdata) {
    eval {
	merge_diff($parser->parse_string($data->{a}),
		   $parser->parse_string($data->{diff}));
    };
    like($@,
	 qr/^XML::DifferenceMarkup merge: invalid diff: /,
	 $data->{name});
}

