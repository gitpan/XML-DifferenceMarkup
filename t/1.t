
use XML::DifferenceMarkup qw(make_diff);

use strict;

our $testdata;

BEGIN {
    $testdata = [
		 {
		  name => 'same docs',
		  a => <<A_SAME_DOCS,
<some>
  <tree/>
</some>
A_SAME_DOCS
		  b => <<B_SAME_DOCS,
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
<node with="attr"/>
A_DIFFERENT_ATTRIBUTES
		  b => <<B_DIFFERENT_ATTRIBUTES,
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
		 {
		  name => 'text node',
		  a => <<A_TEXT_NODE,
<top>
Some text.
</top>
A_TEXT_NODE
		  b => <<B_TEXT_NODE,
<top>
A changed text.
</top>
B_TEXT_NODE
		  diff => <<DIFF_TEXT_NODE
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <top>
    <dm:delete>
Some text.
</dm:delete>
    <dm:insert>
A changed text.
</dm:insert>
  </top>
</dm:diff>
DIFF_TEXT_NODE
		 },
		 {
		  name => 'comment node',
		  a => <<A_COMMENT_NODE,
<textnode>
<!-- with just a comment -->
</textnode>
<!-- note that the comment outside the top node is not preserved -->
A_COMMENT_NODE
		  b => <<B_COMMENT_NODE,
<textnode>
<!-- with a different comment -->
</textnode>
B_COMMENT_NODE
		  diff => <<DIFF_COMMENT_NODE
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <textnode>
    <dm:delete>
<!-- with just a comment -->
    </dm:delete>
    <dm:insert>
<!-- with a different comment -->
    </dm:insert>
  </textnode>
</dm:diff>
DIFF_COMMENT_NODE
                 },
		 {
		  name => 'pruned delete',
		  a => <<A_PRUNED_DELETE,
<a>
<little>
<bit>
<deeper>
<tree>
<with>
<additional>
<nodes/>
</additional>
</with>
</tree>
</deeper>
</bit>
</little>
</a>
A_PRUNED_DELETE
		  b => <<B_PRUNED_DELETE,
<a>
<little>
<bit>
<deeper>
<tree/>
</deeper>
</bit>
</little>
</a>
B_PRUNED_DELETE
		  diff => <<DIFF_PRUNED_DELETE
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <a>
    <little>
      <bit>
        <deeper>
          <tree>
            <dm:delete>
              <with/>
            </dm:delete>
          </tree>
        </deeper>
      </bit>
    </little>
  </a>
</dm:diff>
DIFF_PRUNED_DELETE
		 },
		 {
		  name => 'reorder',
		  a => <<A_REORDER,
<some>text<!-- and comment --></some>
A_REORDER
		  b => <<B_REORDER,
<some><!-- and comment -->text</some>
B_REORDER
		  diff => <<DIFF_REORDER
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <some>
    <dm:delete>text</dm:delete>
    <dm:copy count="1"/>
    <dm:insert>text</dm:insert>
  </some>
</dm:diff>
DIFF_REORDER
		 },
		 {
		  name => 'asymmetric replace',
		  a => <<A_ASYMMETRIC_REPLACE,
<top>
<a/>
<b/>
</top>
A_ASYMMETRIC_REPLACE
		  b => <<B_ASYMMETRIC_REPLACE,
<top>
<x/>
</top>
B_ASYMMETRIC_REPLACE
		  diff => <<DIFF_ASYMMETRIC_REPLACE
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <top>
    <dm:delete>
      <a/>
      <b/>
    </dm:delete>
    <dm:insert>
      <x/>
    </dm:insert>
  </top>
</dm:diff>
DIFF_ASYMMETRIC_REPLACE
		 },
		 {
		  name => 'repeated delete',
		  a => <<A_REPEATED_DELETE,
<top>
<a/>
<b/>
<c/>
<d/>
<e/>
<f/>
</top>
A_REPEATED_DELETE
		  b => <<B_REPEATED_DELETE,
<top>
<d/>
<e/>
<f/>
</top>
B_REPEATED_DELETE
		  diff => <<DIFF_REPEATED_DELETE
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <top>
    <dm:delete>
      <a/>
      <b/>
      <c/>
    </dm:delete>
    <dm:copy count="3"/>
  </top>
</dm:diff>
DIFF_REPEATED_DELETE
		 }
		];
}

use Test::More tests => scalar @$testdata;

my $parser = XML::LibXML->new();
$parser->keep_blanks(0);

foreach my $data (@$testdata) {
    my $dom = make_diff($parser->parse_string($data->{a}),
			$parser->parse_string($data->{b}));
    is($dom->toString(1), $data->{diff}, $data->{name});
}

