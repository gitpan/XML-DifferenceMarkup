
use XML::DifferenceMarkup qw(make_diff merge_diff);

use strict;

our $testdata;

BEGIN {
    $testdata = [
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
		  name => 'text node',
		  a => <<A_TEXT_NODE,
<?xml version="1.0"?>
<top>
Some text.
</top>
A_TEXT_NODE
		  b => <<B_TEXT_NODE,
<?xml version="1.0"?>
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
<?xml version="1.0"?>
<textnode>
<!-- with just a comment -->
</textnode>
<!-- note that the comment outside the top node is not preserved -->
A_COMMENT_NODE
		  b => <<B_COMMENT_NODE,
<?xml version="1.0"?>
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
		  name => 'processing instruction node',
		  a => <<A_PI_NODE,
<?xml version="1.0"?>
<textnode>
<?do something?>
</textnode>
<!-- note that the comment outside the top node is not preserved -->
A_PI_NODE
		  b => <<B_PI_NODE,
<?xml version="1.0"?>
<textnode>
<?dont do it yet?>
</textnode>
B_PI_NODE
		  diff => <<DIFF_PI_NODE
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <textnode>
    <dm:delete>
<?do something?>
    </dm:delete>
    <dm:insert>
<?dont do it yet?>
    </dm:insert>
  </textnode>
</dm:diff>
DIFF_PI_NODE
                 },
		 {
		  name => 'pruned delete',
		  a => <<A_PRUNED_DELETE,
<?xml version="1.0"?>
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
<?xml version="1.0"?>
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
		  name => 'repeated delete',
		  a => <<A_REPEATED_DELETE,
<?xml version="1.0"?>
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
<?xml version="1.0"?>
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
		 },
		 {
		  name => 'reorder',
		  a => <<A_REORDER,
<?xml version="1.0"?>
<some>text<!-- and comment --></some>
A_REORDER
		  b => <<B_REORDER,
<?xml version="1.0"?>
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
		  name => 'repetitive',
		  a => <<A_REPETITIVE,
<?xml version="1.0"?>
<repetitive>
  <a/>
  <a/>
  <a/>
  <a/>
  <a/>
  <a/>
</repetitive>
A_REPETITIVE
		  b => <<B_REPETITIVE,
<?xml version="1.0"?>
<repetitive>
  <a/>
  <a/>
</repetitive>
B_REPETITIVE
		  diff => <<DIFF_REPETITIVE
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <repetitive>
    <dm:copy count="2"/>
    <dm:delete>
      <a/>
      <a/>
      <a/>
      <a/>
    </dm:delete>
  </repetitive>
</dm:diff>
DIFF_REPETITIVE
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
    <dm:insert>
      <x/>
    </dm:insert>
  </top>
</dm:diff>
DIFF_ASYMMETRIC_REPLACE
		 },		 
		 { # 5Sep2002: added to expose an incorect use of _prune
		  name => 'deep asymmetric replace',
		  a => <<A_DEEP_ASYMMETRIC_REPLACE,
<?xml version="1.0"?>
<top>
  <a/>
  <b>
    <with/> a subtree
  </b>
</top>
A_DEEP_ASYMMETRIC_REPLACE
		  b => <<B_DEEP_ASYMMETRIC_REPLACE,
<?xml version="1.0"?>
<top>
  <x/>
</top>
B_DEEP_ASYMMETRIC_REPLACE
# 5Sep2002: the extra namespace declaration is ugly...
		  diff => <<DIFF_DEEP_ASYMMETRIC_REPLACE
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
DIFF_DEEP_ASYMMETRIC_REPLACE
		 },
		 {
		  name => 'insert below delete',
		  a => <<A_INSERT_BELOW_DELETE,
<?xml version="1.0"?>
<page attr="1">
  <word value="Arbeiter"/>
  <word value="Kopf"/>
</page>
A_INSERT_BELOW_DELETE
		  b => <<B_INSERT_BELOW_DELETE,
<?xml version="1.0"?>
<page attr="1">
  <word value="Kopf">
    <trans value="hlava"/>
  </word>
</page>
B_INSERT_BELOW_DELETE
# 14Sep2002: the extra namespace declaration is ugly...
		  diff => <<DIFF_INSERT_BELOW_DELETE,
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <page attr="1">
    <dm:delete>
      <word value="Arbeiter"/>
    </dm:delete>
    <word value="Kopf">
      <dm:insert>
        <trans value="hlava"/>
      </dm:insert>
    </word>
  </page>
</dm:diff>
DIFF_INSERT_BELOW_DELETE
		 },
		 {
		  name => 'two changes',
		  a => <<A_TWO_CHANGES,
<?xml version="1.0"?>
<a>
  <a2>
    <tree/>
  </a2>
  <a3>another</a3>
</a>
A_TWO_CHANGES
		  b => <<B_TWO_CHANGES,
<?xml version="1.0"?>
<a>
  <a2/>
  <a3>difference</a3>
</a>
B_TWO_CHANGES
		  diff => <<DIFF_TWO_CHANGES
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <a>
    <a2>
      <dm:delete>
        <tree/>
      </dm:delete>
    </a2>
    <a3>
      <dm:delete>another</dm:delete>
      <dm:insert>difference</dm:insert>
    </a3>
  </a>
</dm:diff>
DIFF_TWO_CHANGES
		 },
		 {
		  name => 'balanced traversal',
		  a => <<A_BALANCED_TRAVERSAL,
<?xml version="1.0"?>
<a>
  <a2>
    <mostly>
      <but>
        <not>
          <entirely>
            <same>
              <tree/>
            </same>
          </entirely>
        </not>
      </but>
    </mostly>
  </a2>
  <a3>another</a3>
</a>
A_BALANCED_TRAVERSAL
		  b => <<B_BALANCED_TRAVERSAL,
<?xml version="1.0"?>
<a>
  <a2>
    <mostly>
      <but>
        <not>
          <entirely>
            <same/>
          </entirely>
        </not>
      </but>
    </mostly>
  </a2>
  <a3>difference</a3>
</a>
B_BALANCED_TRAVERSAL
		  diff => <<DIFF_BALANCED_TRAVERSAL
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <a>
    <a2>
      <mostly>
        <but>
          <not>
            <entirely>
              <same>
                <dm:delete>
                  <tree/>
                </dm:delete>
              </same>
            </entirely>
          </not>
        </but>
      </mostly>
    </a2>
    <a3>
      <dm:delete>another</dm:delete>
      <dm:insert>difference</dm:insert>
    </a3>
  </a>
</dm:diff>
DIFF_BALANCED_TRAVERSAL
		 },
		 {
		  name => 'extracted db dump',
		  a => <<A_EXTRACTED_DB_DUMP,
<?xml version="1.0"?>
<table>
<word value="reordered">
<trans value="a"/>
<trans value="b"/>
<trans value="c"/>
</word>
<word value="leidenschaftlich"/>
<word value="leider"/>
</table>
A_EXTRACTED_DB_DUMP
		  b => <<B_EXTRACTED_DB_DUMP,
<?xml version="1.0"?>
<table>
  <word value="reordered">
    <trans value="b"/>
    <trans value="c"/>
    <trans value="a"/>
  </word>
  <word value="leidenschaftlich"/>
  <word value="leider"/>
</table>
B_EXTRACTED_DB_DUMP
		  diff => <<DIFF_EXTRACTED_DB_DUMP
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <table>
    <word value="reordered">
      <dm:delete>
        <trans value="a"/>
      </dm:delete>
      <dm:copy count="2"/>
      <dm:insert>
        <trans value="a"/>
      </dm:insert>
    </word>
    <dm:copy count="2"/>
  </table>
</dm:diff>
DIFF_EXTRACTED_DB_DUMP
		 },
		 {
		  name => 'suboptimal',
		  a => <<A_SUBOPTIMAL,
<?xml version="1.0"?>
<top>
  <a>
    <with>
a tree it would be nice to keep in the common subset
</with>
  </a>
  <a/>
  <x/>
  <x/>
</top>
A_SUBOPTIMAL
		  b => <<B_SUBOPTIMAL,
<?xml version="1.0"?>
<top>
  <x/>
  <x/>
  <a>
    <with>
a tree it would be nice to keep in the common subset
</with>
  </a>
  <a/>
</top>
B_SUBOPTIMAL
		  diff => <<DIFF_SUBOPTIMAL,
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <top>
    <dm:delete>
      <a/>
      <a/>
    </dm:delete>
    <dm:copy count="2"/>
    <dm:insert>
      <a>
        <with>
a tree it would be nice to keep in the common subset
</with>
      </a>
      <a/>
    </dm:insert>
  </top>
</dm:diff>
DIFF_SUBOPTIMAL
		 }
		];
}

use Test::More tests => 2 * scalar @$testdata;

sub scrub {
    my $doc = shift;

    $doc =~ s~<(dm[0-9]*):(?!diff)([a-z0-9]+)\s+xmlns:\1="http://www.locus.cz/XML/DifferenceMarkup"~<$1:$2~g;

    $doc =~ s~<([a-z0-9]+)\s+xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup"~<$1~g;

    return $doc;
}

my $parser = XML::LibXML->new();
$parser->keep_blanks(0);

foreach my $data (@$testdata) {
    my $a = $parser->parse_string($data->{a});
    my $b = $parser->parse_string($data->{b});

    my $diff = make_diff($a, $b);
    is(scrub($diff->toString(1)), $data->{diff},
        $data->{name} . ' (diff)');

    my $merge = merge_diff($a, $diff);
    is($merge->toString(1), $data->{b}, $data->{name} . ' (merge)');
}

