
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
		  name => 'different docs',
		  a => <<A_DIFFERENT_DOCS,
<?xml version="1.0"?>
  <old>
    <tree>
      <with>
        <some>
          <subtree/>
        </some>
      </with>
    </tree>
  </old>
A_DIFFERENT_DOCS
		  b => <<B_DIFFERENT_DOCS,
<?xml version="1.0"?>
<new>
  <tree>with the whole subtree, of course</tree>
</new>
B_DIFFERENT_DOCS
		  diff => <<DIFF_DIFFERENT_DOCS
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <dm:delete>
    <old/>
  </dm:delete>
  <dm:insert>
    <new>
      <tree>with the whole subtree, of course</tree>
    </new>
  </dm:insert>
</dm:diff>
DIFF_DIFFERENT_DOCS
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
		  name => 'unordered attributes',
		  a => <<A_UNORDERED_ATTRIBUTES,
<?xml version="1.0"?>
<top a="1" c="3" b="2"/>
A_UNORDERED_ATTRIBUTES
		  b => <<B_UNORDERED_ATTRIBUTES,
<?xml version="1.0"?>
<top b="2" a="1" c="3"/>
B_UNORDERED_ATTRIBUTES
		  diff => <<DIFF_UNORDERED_ATTRIBUTES
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <dm:delete>
    <top a="1" c="3" b="2"/>
  </dm:delete>
  <dm:insert>
    <top b="2" a="1" c="3"/>
  </dm:insert>
</dm:diff>
DIFF_UNORDERED_ATTRIBUTES
		 },
		 {
		  name => 'whitespace between attributes',
		  a => <<A_WHITESPACE_BETWEEN_ATTRIBUTES,
<?xml version="1.0"?>
<node a="a"  b="b"/>
A_WHITESPACE_BETWEEN_ATTRIBUTES
		  b => <<B_WHITESPACE_BETWEEN_ATTRIBUTES,
<?xml version="1.0"?>
<node a="a" b="b"/>
B_WHITESPACE_BETWEEN_ATTRIBUTES
		  diff => <<DIFF_WHITESPACE_BETWEEN_ATTRIBUTES
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <dm:copy count="1"/>
</dm:diff>
DIFF_WHITESPACE_BETWEEN_ATTRIBUTES
		 },
		 {
		  name => 'attribute quotes',
		  a => <<A_ATTRIBUTE_QUOTES,
<?xml version="1.0"?>
<node a="a" b='b'/>
A_ATTRIBUTE_QUOTES
		  b => <<B_ATTRIBUTE_QUOTES,
<?xml version="1.0"?>
<node a='a' b="b"/>
B_ATTRIBUTE_QUOTES
		  diff => <<DIFF_ATTRIBUTE_QUOTES
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <dm:copy count="1"/>
</dm:diff>
DIFF_ATTRIBUTE_QUOTES
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
# 5Sep2002: the extra namespace declaration is ugly...
		  diff => <<DIFF_PRUNED_DELETE
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <a>
    <little>
      <bit>
        <deeper>
          <tree xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
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
		  name => 'delete before copy',
		  a => <<A_DELETE_BEFORE_COPY,
<?xml version="1.0"?>
<delta>
<uri value="first">
<word value="1."/>
</uri>
<uri value="second">
<word value="2."/>
</uri>
<uri value="third">
<word value="3."/>
</uri>
<uri value="fourth">
<word value="4."/>
</uri>
</delta>
A_DELETE_BEFORE_COPY
		  b => <<B_DELETE_BEFORE_COPY,
<?xml version="1.0"?>
<delta>
<uri value="first">
<word value="1."/>
</uri>
<uri value="second">
<word value="2."/>
</uri>
<uri value="fourth">
<word value="4."/>
</uri>
</delta>
B_DELETE_BEFORE_COPY
		  diff => <<DIFF_DELETE_BEFORE_COPY,
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <delta>
    <dm:copy count="2"/>
    <dm:delete>
      <uri value="third"/>
    </dm:delete>
    <dm:copy count="1"/>
  </delta>
</dm:diff>
DIFF_DELETE_BEFORE_COPY
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
<?xml version="1.0"?>
<top>
<a/>
<b/>
</top>
A_ASYMMETRIC_REPLACE
		  b => <<B_ASYMMETRIC_REPLACE,
<?xml version="1.0"?>
<top>
<x/>
</top>
B_ASYMMETRIC_REPLACE
# 5Sep2002: the extra namespace declaration is ugly...
		  diff => <<DIFF_ASYMMETRIC_REPLACE
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <top>
    <dm:delete>
      <a/>
      <b/>
    </dm:delete>
    <dm:insert xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
      <x/>
    </dm:insert>
  </top>
</dm:diff>
DIFF_ASYMMETRIC_REPLACE
		 },		 
		 { # 5Sep2002: added to expose an incorect use of _prune
		  name => 'deep asymmetric replace',
		  a => <<A_DEEP_ASYMMETRIC_DELETE,
<?xml version="1.0"?>
<top>
<a/>
<b>
<with/> a subtree
</b>
</top>
A_DEEP_ASYMMETRIC_DELETE
		  b => <<B_DEEP_ASYMMETRIC_DELETE,
<?xml version="1.0"?>
<top>
<x/>
</top>
B_DEEP_ASYMMETRIC_DELETE
# 5Sep2002: the extra namespace declaration is ugly...
		  diff => <<DIFF_DEEP_ASYMMETRIC_DELETE
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <top>
    <dm:delete>
      <a/>
      <b/>
    </dm:delete>
    <dm:insert xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
      <x/>
    </dm:insert>
  </top>
</dm:diff>
DIFF_DEEP_ASYMMETRIC_DELETE
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

