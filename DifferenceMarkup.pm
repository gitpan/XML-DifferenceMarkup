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
C<http://www.locus.cz/XML/DifferenceMarkup> .

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

Instruction nodes are never nested; all nodes above them (except the
top-level <diff/>) come from the input trees. A node from the input
tree is included in the output diff to provide context for instruction
nodes when all of the following is true:

=over

=item * it's an element node

=item * it has the same name in both input trees

=item * it has the same attributes (both names and values)

=item * its subtree is not the same

=back

=head1 BUGS

=over

=item * the diff format has no merge

=item * namespace prefix collision is not handled

=item * information outside the top-level node is not processed

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

$VERSION = '0.02';

# interface (free functions)

sub make_diff {
    my $dm = XML::DifferenceMarkup->new;
    return $dm->diff(@_);
}

# implementation (OO)

sub new {
    my $class = shift;

    # warn "new\n";

    my $self = { nsurl => 'http://www.locus.cz/XML/DifferenceMarkup',
		 nsprefix => 'dm' };
    return bless $self, $class;
}

sub diff {
    my ($self, $d1, $d2) = @_;

    # warn "diff\n";

    $self->{dest} = XML::LibXML::Document->createDocument;
    $self->{growth_point} = $self->{dest}->createElementNS(
        $self->{nsurl},
        $self->_get_scoped_name('diff'));
    $self->{dest}->setDocumentElement($self->{growth_point});

    my $m = $d1->documentElement();
    my $n = $d2->documentElement();

    if ($m->toString eq $n->toString) {
	my $copy = $self->{dest}->createElement(
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

    if ($m->nodeName ne $n->nodeName) {
	return 0;
    }

    my %attr;

    my @ma = $m->attributes;
    foreach my $a (@ma) {
	my $name = $a->nodeName;
	if (exists($attr{$name})) {
	    die "internal error: repeated attribute: $name";
	}

	$attr{$name} = $a->nodeValue;
    }

    my @na = $n->attributes;
    foreach my $a (@na) {
	my $name = $a->nodeName;
	if (!exists($attr{$name})) {
	    return 0;
	}

	if ($attr{$name} ne $a->nodeValue) {
	    return 0;
	}

	delete $attr{$name};
    }

    return scalar(keys(%attr)) == 0;
}

# insert a bottom pair
sub _replace {
    my ($self, $m, $n) = @_;

    # warn "_replace\n";

    my $del = $self->{dest}->createElement(
        $self->_get_scoped_name('delete'));
    $self->{growth_point}->appendChild($del);

    # 1Sep2002: lower-level implementation might be more efficient -
    # or it might not...
    my $tip = $m->cloneNode(1);
    $self->_prune($tip);

    $del->appendChild($self->{dest}->importNode($tip));

    $self->_append_insert($n);
}

sub _append_insert {
    my ($self, $n) = @_;

    # warn "_append_insert(" . $self . ", " . $n->nodeName . ")\n";

    my $ins = $self->{dest}->createElement(
        $self->_get_scoped_name('insert'));
    $self->{growth_point}->appendChild($ins);
    $ins->appendChild($self->{dest}->importNode($n));
}

sub _append_delete {
    my ($self, $n) = @_;

    # warn "_append_delete(" . $self . ", " . $n->nodeName . ")\n";

    my $del = $self->{dest}->createElement(
        $self->_get_scoped_name('delete'));
    $self->{growth_point}->appendChild($del);
    $del->appendChild($self->{dest}->importNode($n));
}

sub _descend {
    my ($self, $m, $n) = @_;

    # warn "_descend\n";

    my $seq = $self->{dest}->createElement($n->nodeName);
    my @attr = $n->attributes;
    foreach (@attr) {
	$seq->setAttribute($_->nodeName, $_->nodeValue);
    }

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

    my $d1 = XML::LibXML::Document->createDocument;
    $d1->setDocumentElement($d1->importNode($m));

    my $d2 = XML::LibXML::Document->createDocument;
    $d2->setDocumentElement($d2->importNode($n));

    my $dm = XML::DifferenceMarkup->new;
    my $dom = $dm->diff($d1, $d2);
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

# remove children of a node (note that the result is different than
# cloneNode(0) - the attributes are kept)
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
    if (!$last || $last->nodeName ne $self->_get_scoped_name('copy')) {
	$last = $self->{dest}->createElement(
            $self->_get_scoped_name('copy'));
	$self->{growth_point}->appendChild($last);
	$count = 1;
    } else {
	$count = 1 + $last->getAttribute('count');
    }

    $last->setAttribute('count', $count);
}

1;
