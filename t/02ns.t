
use XML::DifferenceMarkup qw(make_diff);

use strict;

our $testdata;

BEGIN {
    $testdata = [
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

