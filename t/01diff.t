
use XML::DifferenceMarkup qw(make_diff);

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
		 {
		  name => 'no version',
		  a => <<A_NO_VERSION,
<some><tree/></some>
A_NO_VERSION
		  b => <<B_NO_VERSION,
<some>
  <tree/>
</some>
B_NO_VERSION
		  diff => <<DIFF_NO_VERSION
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <dm:copy count="1"/>
</dm:diff>
DIFF_NO_VERSION
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
		  name => 'different docs',
		  a => <<A_DIFFERENT_DOCS,
<?xml version="1.0"?>
  <w:old xmlns:w="http://random.old.com/a/">
    <tree>
      <with>
        <some>
          <subtree/>
        </some>
      </with>
    </tree>
  </w:old>
A_DIFFERENT_DOCS
		  b => <<B_DIFFERENT_DOCS,
<?xml version="1.0"?>
<new xmlns:e="http://random.new.com/b/">
  <e:tree>with the whole subtree, of course</e:tree>
</new>
B_DIFFERENT_DOCS
		  diff => <<DIFF_DIFFERENT_DOCS
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <dm:delete>
    <w:old xmlns:w="http://random.old.com/a/"/>
  </dm:delete>
  <dm:insert>
    <new xmlns:e="http://random.new.com/b/">
      <e:tree>with the whole subtree, of course</e:tree>
    </new>
  </dm:insert>
</dm:diff>
DIFF_DIFFERENT_DOCS
		 },
		 {
		  name => 'extra ns node',
		  a => <<A_EXTRA_NS_NODE,
<?xml version="1.0"?>
  <old xmlns:w="http://random.old.com/a/">
    <w:tree/>
  </old>
A_EXTRA_NS_NODE
		  b => <<B_EXTRA_NS_NODE,
<?xml version="1.0"?>
<new/>
B_EXTRA_NS_NODE
# 8Sep2002: note that the 'w' namespace isn't needed any more; the
# diff keeps it even if there are no nodes using it
		  diff => <<DIFF_EXTRA_NS_NODE
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <dm:delete>
    <old xmlns:w="http://random.old.com/a/"/>
  </dm:delete>
  <dm:insert>
    <new/>
  </dm:insert>
</dm:diff>
DIFF_EXTRA_NS_NODE
		 },
		 {
		  name => 'namespace without prefix',
		  a => <<A_NAMESPACE_WITHOUT_PREFIX,
<root>
</root>
A_NAMESPACE_WITHOUT_PREFIX
		  b => <<B_NAMESPACE_WITHOUT_PREFIX,
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="cs" lang="cs">
</html>
B_NAMESPACE_WITHOUT_PREFIX
		  diff => <<DIFF_NAMESPACE_WITHOUT_PREFIX
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <dm:delete>
    <root/>
  </dm:delete>
  <dm:insert>
    <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="cs" lang="cs">
</html>
  </dm:insert>
</dm:diff>
DIFF_NAMESPACE_WITHOUT_PREFIX
		 },
		 {
		  name => 'different DTD',
		  a => <<A_DIFFERENT_DTD,
<root>
</root>
A_DIFFERENT_DTD
		  b => <<B_DIFFERENT_DTD,
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
	"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>
</html>
B_DIFFERENT_DTD
		  diff => <<DIFF_DIFFERENT_DTD
<?xml version="1.0"?>
<dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
  <dm:delete>
    <root/>
  </dm:delete>
  <dm:insert>
    <html xmlns="http://www.w3.org/1999/xhtml"/>
  </dm:insert>
</dm:diff>
DIFF_DIFFERENT_DTD
		 },
		 {
		  name => 'taken prefix unused',
		  a => <<A_TAKEN_PREFIX_UNUSED,
<?xml version="1.0"?>
<dm:node xmlns:dm="http://www.deadmouse.com/"/>
A_TAKEN_PREFIX_UNUSED
		  b => <<B_TAKEN_PREFIX_UNUSED,
<?xml version="1.0"?>
<dm:node xmlns:dm="http://www.deadmouse.com/"/>
B_TAKEN_PREFIX_UNUSED
		  diff => <<DIFF_TAKEN_PREFIX_UNUSED
<?xml version="1.0"?>
<dm2:diff xmlns:dm2="http://www.locus.cz/XML/DifferenceMarkup">
  <dm2:copy count="1"/>
</dm2:diff>
DIFF_TAKEN_PREFIX_UNUSED
		 },
		 {
		  name => 'taken prefix used',
		  a => <<A_TAKEN_PREFIX_USED,
<?xml version="1.0"?>
<dm:old xmlns:dm="http://www.deadmouse.com/"/>
A_TAKEN_PREFIX_USED
		  b => <<B_TAKEN_PREFIX_USED,
<?xml version="1.0"?>
<dm:new xmlns:dm="http://www.deadmouse.com/"/>
B_TAKEN_PREFIX_USED
		  diff => <<DIFF_TAKEN_PREFIX_USED
<?xml version="1.0"?>
<dm2:diff xmlns:dm2="http://www.locus.cz/XML/DifferenceMarkup">
  <dm2:delete>
    <dm:old xmlns:dm="http://www.deadmouse.com/"/>
  </dm2:delete>
  <dm2:insert>
    <dm:new xmlns:dm="http://www.deadmouse.com/"/>
  </dm2:insert>
</dm2:diff>
DIFF_TAKEN_PREFIX_USED
		 }
		];
}

use Test::More tests => scalar @$testdata;

# 21Sep2002: It would be better to compare canonicalized docs, but
# since there's no support for XML canonicalization in LibXML... Using
# isSameNode on the document element is also possible, but the
# document element isn't the whole document, and we *want* to test the
# serialized version...

sub scrub_elem {
    my ($elem, $doc) = @_;

    $doc =~ s~<(dm[0-9]*):$elem\s+xmlns:\1="http://www.locus.cz/XML/DifferenceMarkup"~<$1:$elem~g;
    return $doc;
}

sub scrub {
    my $doc = shift;

    return scrub_elem('copy',
        scrub_elem('delete', scrub_elem('insert', $doc)));
}

my $parser = XML::LibXML->new();
$parser->keep_blanks(0);

foreach my $data (@$testdata) {
    my $dom = make_diff($parser->parse_string($data->{a}),
			$parser->parse_string($data->{b}));
    is(scrub($dom->toString(1)), $data->{diff}, $data->{name});
}

