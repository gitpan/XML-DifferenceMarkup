=head1 NAME

XML::DifferenceMarkup

=head1 SYNOPSIS

 use XML::DifferenceMarkup qw(make_diff);

 $parser = XML::LibXML->new();
 $parser->keep_blanks(0);
 $d1 = $parser->parse_file($fname1);
 $d2 = $parser->parse_file($fname2);

 $dom = make_diff($d1, $d2);
 print $dom->toString(1);

=head1 REQUIRES

XML::LibXML, Algorithm::Diff

=head1 DESCRIPTION

This module implements an XML diff producing XML output. Both input
and output of C<make_diff> (the only function exported by the module)
are DOM documents, as implemented by XML::LibXML. The output format is
meant to be human-readable (i.e. simple, as opposed to short) -
basically the diff is a subset of the input trees, annotated with
instruction element nodes specifying how to convert the source tree to
the target by inserting and deleting nodes. To prevent name colisions
with input trees, all added elements are in a namespace
C<http://www.locus.cz/XML/DifferenceMarkup> (the diff will fail on
input trees which already use that namespace).

The top-level node of the diff is always <diff/> (or rather <dm:diff
xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup"> ... </dm:diff> -
this description elides the namespace specification from now on);
under it are fragments of the input trees and instruction nodes:
<insert/>, <delete/> and <copy/>. <copy/> is used in places where the
input subtrees are the same - in the limit, the diff of 2 identical
documents is

 <?xml version="1.0"?>
 <dm:diff xmlns:dm="http://www.locus.cz/XML/DifferenceMarkup">
   <dm:copy count="1"/>
 </dm:diff>

(copy always has the count attribute and nothing else). <insert/>
and <delete/> have the obvious meaning - in the limit a diff of 2
documents which have nothing in common is something like

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

Note that <delete/> contains just one level of nested nodes - their
subtrees are not included in the diff (but the element nodes which are
included always come with all their attributes).

Instruction nodes are never nested; all nodes above an instruction
node (except the top-level <diff/>) come from the input trees. A node
from the input tree is included in the output diff to provide context
for instruction nodes when all of the following is true:

=over

=item * it's an element node

=item * it has the same name in both input trees

=item * it has the same attributes (both names and values)

=item * its subtree is not the same

=back

The last condition guarantees that the "contextual" nodes always
contain at least one instruction node.

=head1 BUGS

=over

=item * the diff does not handle changes in attribute ordering

=item * the diff format has no merge

=item * information outside the document element is not processed

=back

=head1 AUTHOR

Vaclav Barta <vbar@comp.cz>

=head1 SEE ALSO

L<XML::LibXML>

=cut

# ' stop the comment highlighting

package XML::DifferenceMarkup;

use XML::LibXML;
use Algorithm::Diff qw(traverse_sequences);

use 5.006;
use strict;
use warnings;

use vars qw(@ISA @EXPORT_OK $VERSION);

require Exporter;

@ISA = qw(Exporter);

@EXPORT_OK = qw(make_diff);

$VERSION = '0.04';

our $nsurl ='http://www.locus.cz/XML/DifferenceMarkup';

# free functions

sub _get_unique_prefix {
    my ($m, $n) = @_;

    # warn "_get_unique_prefix\n";

    my $prefix = 'dm';

    my $col = XML::DifferenceMarkup::NamespaceCollector->new(
        $prefix, $nsurl);
    my $top = $col->get_unused_number($m, $n);

    if ($top != -1) {
	$prefix .= $top;
    }

    # warn "unique prefix: $prefix\n";
    return $prefix;
}

sub make_diff {
    my ($d1, $d2) = @_;

    my $m = $d1->documentElement();
    my $n = $d2->documentElement();

    my $dm = XML::DifferenceMarkup->new(
        _get_unique_prefix($m, $n));

    return $dm->diff_nodes($m, $n);
}

# OO starts here

sub new {
    my ($class, $nsprefix) = @_;

    # warn "new\n";

    my $self = { nsprefix => $nsprefix };
    return bless $self, $class;
}

sub diff_nodes {
    my ($self, $m, $n) = @_;

    $self->{dest} = XML::LibXML::Document->createDocument;
    $self->{growth_point} = $self->{dest}->createElementNS(
        $nsurl,
        $self->_get_scoped_name('diff'));
    $self->{dest}->setDocumentElement($self->{growth_point});

    if ($m->toString eq $n->toString) {
	my $copy = $self->{dest}->createElementNS(
            $nsurl,
            $self->_get_scoped_name('copy'));
	$self->{growth_point}->appendChild($copy);
	$copy->setAttribute('count', 1);
    } else {
  	if (!$self->_eq_shallow($m, $n)) {
	    $self->_replace($m, $n);
	} else {
	    $self->_descend($m, $n);
	}
    }

    return $self->{dest};
}

sub _get_scoped_name {
    my ($self, $tail) = @_;

    return $self->{nsprefix} . ":$tail";
}

sub _eq_shallow {
    my ($self, $m, $n) = @_;

    # warn "_eq_shallow\n";

    # 10Sep2002: this isn't really equality as understood by DOM (the
    # same attributes in different order will be considered
    # different), but it's the same equality as used in other places
    # (most importantly traverse_sequences)

    my $p = $self->_get_tip($m);
    my $q = $self->_get_tip($n);

    return $p->toString eq $q->toString;
}

# insert a bottom pair
sub _replace {
    my ($self, $m, $n) = @_;

    # warn "_replace\n";

    my $del = $self->{dest}->createElementNS(
        $nsurl,
        $self->_get_scoped_name('delete'));
    $self->{growth_point}->appendChild($del);

    $del->appendChild($self->_import_tip($m));
    $self->_append_insert($n);
}

# copy a node to the destination tree, removing its children in the
# process (note that the result is different than cloneNode(0) - the
# attributes are kept)
sub _import_tip {
    my ($self, $n) = @_;

    my $tip = $self->_get_tip($n);
    return $self->{dest}->importNode($tip);
}

sub _get_tip {
    my ($self, $n) = @_;

    my $tip = $n->cloneNode(1);
    $self->_remove_children($tip);
    return $tip;
}

sub _append_insert {
    my ($self, $n) = @_;

    # warn "_append_insert(" . $self . ", " . $n->nodeName . ")\n";

    my $ins = $self->{dest}->createElementNS(
        $nsurl,
        $self->_get_scoped_name('insert'));
    $self->{growth_point}->appendChild($ins);
    $ins->appendChild($self->{dest}->importNode($n));
}

sub _append_delete {
    my ($self, $n) = @_;

    # warn "_append_delete(" . $self . ", " . $n->nodeName . ")\n";

    my $del = $self->{dest}->createElementNS(
        $nsurl,
        $self->_get_scoped_name('delete'));
    $self->{growth_point}->appendChild($del);
    $del->appendChild($self->{dest}->importNode($n));
}

sub _append_copy {
    my $self = shift;

    # warn "_append_copy($self)\n";

    my $copy = $self->{dest}->createElementNS(
        $nsurl,
        $self->_get_scoped_name('copy'));
    $self->{growth_point}->appendChild($copy);
    $copy->setAttribute('count', 1);
}

sub _descend {
    my ($self, $m, $n) = @_;

    # warn "_descend\n";

    my $seq = $self->_import_tip($n);

    $self->{growth_point}->appendChild($seq);
    $self->{growth_point} = $seq;

    my $a = $self->_children($m);
    my $b = $self->_children($n);
    traverse_sequences($a, $b,
		       {
			MATCH => sub {
			    $self->_on_match;
			},
			DISCARD_A => sub {
			    my $i = shift;

			    $self->_on_delete($a->[$i]);
			},
			DISCARD_B => sub {
			    my $i = shift;
			    my $j = shift;

			    $self->_on_insert($b->[$j]);
			}
		       },
		       sub {
			   my $n = shift;

			   return $n->toString;
		       });

    my $last = $seq->lastChild;
    if ($last && $last->nodeName eq
        $self->_get_scoped_name('delete')) {
	# the last <delete/> isn't going to be descended into (because
	# it's the last in the sequence); we can leave only the top
	# node from it & remove the subnodes
	$self->_prune($last);
    }

    # warn "_descend finished\n";
}

sub _children {
    my ($dummy_self, $n) = @_;

    # warn "_children\n";

    my $out = [];

    my $ch = $n->firstChild;
    while ($ch) {
	push @$out, $ch;
	$ch = $ch->nextSibling;
    }

    return $out;
}

sub _diff {
    my ($self, $m, $n) = @_;

    # warn "_diff\n";

    my $dm = XML::DifferenceMarkup->new($self->{nsprefix});
    my $dom = $dm->diff_nodes($m, $n);
    return $dom->documentElement;
}

sub _combine_first_child {
    my ($self, $first_child, $checked_name) = @_;

    my $last = $self->{growth_point}->lastChild;

    if (($last->nodeName ne $checked_name) ||
	($first_child->nodeName ne $checked_name)) {
	return 0;
    }

    my $cnt = $first_child->firstChild;
    while ($cnt) {
	$last->appendChild($self->{dest}->importNode($cnt));
	$cnt = $cnt->nextSibling;
    }

    return 1;
}

# returns 1 OK (dest has been modified), 0 it isn't possible to
# combine the pair (i.e. because one node of the pair is a text node)
sub _combine_pair {
    my ($self, $n, $reverse) = @_;

    # warn "_combine_pair(" . $self . ", " . $n->nodeName . ", " . $reverse . ")\n";

    my $last = $self->{growth_point}->lastChild;
    if (!$last) {
	die "internal error: no last insert";
    }

    my $m = $last->lastChild;
    if (!$m) {
	die "internal error: " . $last->nodeName . " without children";
    }

    # 1 is XML_ELEMENT_NODE
    if (($m->nodeType != 1) ||
	($n->nodeType != 1)) {
	return 0;
    }

    if ($reverse) {
	my $t = $m; $m = $n; $n = $t;
    }

    my $root = $self->_diff($m, $n);
    my $ch = $root->firstChild;
    if (!$ch) {
	die "internal error: empty " . $root->nodeName;
    }

    my $stable = $last->firstChild;
    my $moved = $last->lastChild;
    if ($stable->isSameNode($moved)) {
	# the same node might be immediately created again, but that's
	# just inefficient, whereas leaving an empty insert/delete
	# node in the destination tree is downright incorrect
	$self->{growth_point}->removeChild($last);
    } else {
	$last->removeChild($moved);

	if ($self->_combine_first_child($ch,
                $self->_get_scoped_name('delete')) ||
	    $self->_combine_first_child($ch,
                $self->_get_scoped_name('insert'))) {
	    $ch = $ch->nextSibling;
	}
    }

    while ($ch) {
	$self->{growth_point}->appendChild($self->{dest}->importNode($ch));
	$ch = $ch->nextSibling;
    }

    return 1;
}

sub _on_insert {
    my ($self, $n) = @_;

    # warn "_on_insert(" . $self . ", " . $n->nodeName . ")\n";

    my $last = $self->{growth_point}->lastChild;
    if (!$last) {
	$self->_append_insert($n);
    } elsif ($last->nodeName eq $self->_get_scoped_name('insert')) {
	$last->appendChild($self->{dest}->importNode($n));
    } elsif ($last->nodeName ne $self->_get_scoped_name('delete')) {
	$self->_append_insert($n);
    } else {
	if (!$self->_combine_pair($n, 0)) {
	    $self->_append_insert($n);
	}
    }

    # warn "_on_insert finished\n";
}

sub _on_delete {
    my ($self, $n) = @_;

    # warn "_on_delete(" . $self . ", " . $n->nodeName . ")\n";

    my $last = $self->{growth_point}->lastChild;
    if (!$last) {
	$self->_append_delete($n);
    } elsif ($last->nodeName eq $self->_get_scoped_name('delete')) {
	# the last node under <delete/> isn't going to be descended
	# into (because it's going to be followed by another deleted
	# node); we can leave only the top node from it & remove the
	# subnodes
	$self->_prune($last);
	$last->appendChild($self->{dest}->importNode($n));
    } elsif ($last->nodeName ne $self->_get_scoped_name('insert')) {
	$self->_append_delete($n);
    } else {
	if (!$self->_combine_pair($n, 1)) {
	    $self->_append_delete($n);
	}
    }
}

# remove grandchildren of a node
sub _prune {
    my ($self, $n) = @_;

    # warn "_prune\n";

    my $ch = $n->firstChild;
    while ($ch) {
	$self->_remove_children($ch);
	$ch = $ch->nextSibling;
    }
}

sub _remove_children {
    my ($self, $n) = @_;

    # warn "_remove_children\n";

    my $ch = $n->firstChild;
    while ($ch) {
	my $next = $ch->nextSibling;
	$n->removeChild($ch);
	$ch = $next;
    }
}

sub _on_match {
    my $self = shift;

    # warn "_on_match\n";

    my $last = $self->{growth_point}->lastChild;
    my $count;
    if (!$last) {
	$self->_append_copy;
    } elsif ($last->nodeName ne $self->_get_scoped_name('copy')) {
	if ($last->nodeName eq $self->_get_scoped_name('delete')) {
	    $self->_prune($last);
	}
	$self->_append_copy;
    } else {
	$count = 1 + $last->getAttribute('count');
	$last->setAttribute('count', $count);
    }
}

package XML::DifferenceMarkup::NamespaceCollector;

sub new {
    my ($class, $stem, $nsurl) = @_;

    # keys of the namespaces hashref have the form prefix\nurl
    my $self = { stem => $stem, nsurl => $nsurl, namespaces => { } };

    return bless $self, $class;
}

sub get_unused_number {
    my ($self, $m, $n) = @_;

    $self->_fill($m);
    $self->_fill($n);

    my $stem = $self->{stem};
    my $use_max = 0;
    my $max = 1;
    foreach my $pair (keys %{$self->{namespaces}}) {
	unless ($pair =~ /^(.+)\n(.+)$/) {
	    die "internal error: invalid pair $pair";
	}

	my ($prefix, $url) = ($1, $2);

	if ($url eq $self->{nsurl}) {
	    die "input tree contains the reserved namespace " .
                $self->{nsurl} . "\n";
	}

	if ($prefix eq $stem) {
	    $use_max = 1;
	} elsif ($prefix =~ /^$stem([0-9]+)$/) {
	    if ($1 > $max) {
		$max = $1;
	    }
	}
    }

    return $use_max ? ($max + 1) : -1;
}

sub _fill {
    my ($self, $n) = @_;

    foreach ($n->getNamespaces) {
	unless (defined $_->getData) {
	    # 11Sep2002: LibXML apparently drops the prefix somewhere
	    # during cloning - this case really is't worth
	    # supporting...
	    die "invalid XML: no namespace declaration for prefix " .
	        $_->name . "\n";
	}

	my $pair = $_->name . "\n" . $_->getData;
	$self->{namespaces}->{$pair} = 1;
    }

    my $ch = $n->firstChild;
    while ($ch) {
	$self->_fill($ch);
	$ch = $ch->nextSibling;
    }
}

1;
