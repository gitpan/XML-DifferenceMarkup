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

=head1 DESCRIPTION

This module implements an XML diff producing XML output. Both input
and output are DOM documents, as implemented by XML::LibXML.

The diff format used by XML::DifferenceMarkup is meant to be
human-readable (i.e. simple, as opposed to short) - basically the diff
is a subset of the input trees, annotated with instruction element
nodes specifying how to convert the source tree to the target by
inserting and deleting nodes. To prevent name colisions with input
trees, all added elements are in a namespace
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

(copy always has the count attribute and no other content). <insert/>
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

Actually, the above is a typical output even for documents which have
plenty in common - if (for example) the names of top-level elements in
the two input documents differ, XML::DifferenceMarkup will produce a
maximal diff, even if their subtrees are exactly the same.

Note that <delete/> contains just one level of nested nodes - their
subtrees are not included in the diff (but the element nodes which are
included always come with all their attributes). <insert/> and
<delete/> don't have any attributes and always contain some subtree.

Instruction nodes are never nested; all nodes above an instruction
node (except the top-level <diff/>) come from the input trees. A node
from the input tree is included in the output diff to provide context
for instruction nodes when it satisfies the following conditions:

=over

=item * it's an element node

=item * it has the same name in both input trees

=item * it has the same attributes (names and values) in the same order

=item * its subtree is not the same

=back

The last condition guarantees that the "contextual" nodes always
contain at least one <insert/> or <delete/>.

=head1 FUNCTIONS

Note that XML::DifferenceMarkup functions must be explicitly imported
(i.e. with C<use XML::DifferenceMarkup qw(make_diff merge_diff);>)
before they can be called.

=head2 make_diff

C<make_diff> takes 2 parameters (the input documents) and produces
their diff. Note that the diff is asymmetric - C<make_diff($a, $b)> is
different from C<make_diff($b, $a)>.

=head2 merge_diff

C<merge_diff> takes the first document passed to C<make_diff> and its
return value and produces the second document. (More-or-less - the
document isn't canonicalized, so opinions on its "equality" may
differ.)

=head2 Error Handling

Both C<make_diff> and C<merge_diff> throw exceptions on invalid input
- its own exceptions as well as exceptions thrown by
XML::LibXML. These exceptions can usually (not always, though - it
I<is> possible to construct an input which will crash the calling
process) be catched by calling the functions from an eval block.

=head1 BUGS

=over

=item * attribute order is significant

=item * diff needs just one namespace declaration but usually has more

=item * information outside the document element is not processed

=back

=head1 AUTHOR

Vaclav Barta <vbar@comp.cz>

=head1 SEE ALSO

L<XML::LibXML>

=cut

# ' stop the comment highlighting

package XML::DifferenceMarkup;

use 5.006;
use strict;
use warnings;

use vars qw(@ISA @EXPORT_OK $VERSION);

require Exporter;

@ISA = qw(Exporter);

@EXPORT_OK = qw(make_diff merge_diff);

$VERSION = '0.06';

our $NSURL = 'http://www.locus.cz/XML/DifferenceMarkup';

sub _get_unique_prefix {
    my ($m, $n) = @_;

    # warn "_get_unique_prefix\n";

    my $prefix = 'dm';

    my $col = XML::DifferenceMarkup::NamespaceCollector->new(
        $prefix, $NSURL);
    my $top = $col->get_unused_number($m, $n);

    if ($top != -1) {
	$prefix .= $top;
    }

    # warn "unique prefix: $prefix\n";
    return $prefix;
}

sub make_diff {
    my ($d1, $d2) = @_;

    my $m = $d1->documentElement;
    my $n = $d2->documentElement;

    my $dm = XML::DifferenceMarkup::Diff->new(
        _get_unique_prefix($m, $n),
        $NSURL);

    return $dm->diff_nodes($m, $n);
}

sub merge_diff {
    my ($src_doc, $diff_doc) = @_;

    my $builder = XML::DifferenceMarkup::Merge->new($NSURL);
    return $builder->merge(
        $src_doc,
        $diff_doc->documentElement);
}

package XML::DifferenceMarkup::Merge;

use strict;
use warnings;

use vars qw(@ISA);

@ISA = qw(XML::DifferenceMarkup::Target);

sub new {
    my ($class, $nsurl) = @_;

#    warn "new\n";

    my $self = XML::DifferenceMarkup::Target::new($class, $nsurl);
    $self->{die_head} = 'XML::DifferenceMarkup merge: invalid diff: ';

    return $self;
}

sub merge {
    my ($self, $src_tree, $diff_node) = @_;

    # warn "merge\n";

    $self->{src} = $src_tree;
    $self->{src_point} = $src_tree->documentElement;
    # warn "src_point := " . $self->{src_point}->nodeName;

    $self->{nsprefix} = $self->_get_nsprefix($diff_node);
    $self->_check_top_node_name($diff_node);

    $self->{dest} = XML::LibXML::Document->createDocument;

    my $ch = $diff_node->firstChild;
    unless ($ch) {
	die $self->{die_head} . "diff node has no children\n";
    }

    $self->_do_merge($ch);
    $ch = $ch->nextSibling;

    while ($ch) {
	$self->_do_merge($ch);
	$ch = $ch->nextSibling;
    }

    return $self->{dest};
}

sub _do_merge {
    my ($self, $tree) = @_;

    # warn "_do_merge\n";

    my $name = $tree->nodeName;

    if ($name eq $self->get_scoped_name('delete')) {
	$self->_handle_delete($tree);
    } elsif ($name eq $self->get_scoped_name('copy')) {
	$self->_handle_copy($tree);
    } elsif ($name eq $self->get_scoped_name('insert')) {
	$self->_handle_insert($tree);
    } else {
	# should check that the node isn't in the dm namespace
	$self->_copy_shallow;

	my $ch = $tree->firstChild;
	while ($ch) {
	    $self->_do_merge($ch);
	    $ch = $ch->nextSibling;
	}

	$self->_elevate_dest_point;
    }
}

sub _handle_delete {
    my ($self, $delete_instruction) = @_;

    # warn "_handle_delete\n";

    my $ch = $delete_instruction->firstChild;
    unless ($ch) {
	die $self->{die_head} . "delete node has no children\n";
    }

    my $old = $self->{src_point};

    unless ($self->{src_point}) {
	die $self->{die_head} . "nothing to delete\n";
    }

    my $finished = 0;
    while ($ch) {
	# should check that the deleted node is the same in source &
	# diff...

	my $checked_sibling = $self->{src_point}->nextSibling;
	if ($checked_sibling) {
	    $self->{src_point} = $checked_sibling;
	    my $src_point_str = $self->{src_point}->nodeName;
	    # warn "src_point := $src_point_str";
	} else {
	    $finished = 1;
	}

	$ch = $ch->nextSibling;
    }

    if ($finished) {
	my $top = $self->{src}->documentElement;
	if (!$old->isSameNode($top)) {
	    my $previous = $old->parentNode;
	    if (!$previous->isSameNode($top)) {
		$self->_elevate_src_point($previous);
	    }
	}
    }
}

sub _advance_src_point {
    my $self = shift;

    my $sibling = $self->{src_point}->nextSibling;
    if ($sibling) {
	$self->{src_point} = $sibling;
	# warn "src_point := " . $self->{src_point}->nodeName . "\n";
    } else {
	my $top = $self->{src}->documentElement;
	if (!$self->{src_point}->isSameNode($top)) {
	    my $previous = $self->{src_point}->parentNode;
	    if (!$previous->isSameNode($top)) {
		$self->_elevate_src_point($previous);
	    }
	}
    }
}

sub _elevate_src_point {
    my ($self, $previous) = @_;

    # warn "_elevate_src_point(" . $previous->nodeName . ")\n";

    my $top = $self->{src}->documentElement;

    while (!($previous->nextSibling)) {
	if ($previous->isSameNode($top)) {
	    # warn "wrapping up...\n";
	    return;
	}

	$previous = $previous->parentNode;
	# warn "source point going up to " . $previous->nodeName . "\n";
    }

    $self->{src_point} = $previous->nextSibling;
    # my $src_point_str = $self->{src_point} ? $self->{src_point}->nodeName : 'undef';
    # warn "src_point := $src_point_str";
}

sub _elevate_dest_point {
    my $self = shift;

    # warn "_elevate_dest_point\n";

    my $top = $self->{dest}->documentElement;
    if (!$self->{dest_point}->isSameNode($top)) {
	$self->{dest_point} = $self->{dest_point}->parentNode;
	# my $dest_point_str = $self->{dest_point} ? $self->{dest_point}->nodeName : 'undef';
	# warn "dest_point := $dest_point_str";
    }
}

sub _handle_insert {
    my ($self, $insert_instruction) = @_;

    # warn "_handle_insert\n";

    my $ch = $insert_instruction->firstChild;
    unless ($ch) {
	die $self->{die_head} . "insert node has no children\n";
    }

    while ($ch) {
	my $new = $self->{dest}->importNode($ch);
	$self->_append($new);

	$ch = $ch->nextSibling;
    }
}

sub _handle_copy {
    my ($self, $copy_instruction) = @_;

    # warn "_handle_copy\n";

    unless ($self->{src_point}) {
	die $self->{die_head} . "nothing to copy\n";
    }

    my $count = $copy_instruction->getAttribute('count');
    unless ($count > 0) {
	die $self->{die_head} . "invalid copy count $count\n";
    }

    while ($count > 0) {
	$self->_copy_deep;
	--$count;
    }
}

# Copies $self->{src_point} (without its subtree) to the target
# document.
sub _copy_shallow {
    my $self = shift;

    # warn "_copy_shallow\n";

    unless ($self->{src_point}) {
	die $self->{die_head} . "nothing to shallow-copy\n";
    }

    my $new = $self->import_tip($self->{src_point});
    $self->_append($new);

    my $checked_child = $self->{src_point}->firstChild;
    if ($checked_child) {
	$self->{src_point} = $checked_child;
	# my $src_point_str = $self->{src_point}->nodeName;
	# warn "src_point := $src_point_str";
    } else {
	$self->_advance_src_point;
    }

    $self->{dest_point} = $new;
    # my $dest_point_str = $self->{dest_point} ? $self->{dest_point}->nodeName : 'undef';
    # warn "dest_point := $dest_point_str";
}

sub _copy_deep {
    my $self = shift;

    # warn "_copy_deep\n";

    unless ($self->{src_point}) {
	die $self->{die_head} . "nothing to deep-copy\n";
    }

    my $new = $self->{dest}->importNode($self->{src_point});
    $self->_append($new);

    $self->_advance_src_point;
}

sub _append {
    my ($self, $new) = @_;

    # warn "_append(" . $new->nodeName . ")\n";

    if (!exists($self->{dest_point})) {
	$self->{dest}->setDocumentElement($new);
    } else {
	$self->{dest_point}->appendChild($new);
    }
}

sub _check_top_node_name {
    my ($self, $diff_node) = @_;

    # warn "_check_top_node_name\n";

    my $nsprefix = $self->{nsprefix};

    unless ($diff_node->nodeName =~ /^$nsprefix:diff$/) {
	die $self->{die_head} . "invalid document node " . $diff_node->nodeName . "\n";
    }
}

sub _get_nsprefix {
    my ($self, $diff_node) = @_;

    # warn "_get_nsprefix\n";

    my @dm_ns = $diff_node->getNamespaces;
    if (!@dm_ns) {
	die $self->{die_head} . "document node has no namespace declarations\n";
    }
    if (@dm_ns > 1) {
	my $dm_ns_text = join ', ', map { '"' . $_->getData . '"'; } @dm_ns;
	die $self->{die_head} . "document node has too many namespace declarations: $dm_ns_text\n";
    }

    my $dm_ns = $dm_ns[0];

    my $dm_ns_url = $dm_ns->getData;
    if ($dm_ns_url ne $NSURL) {
	die $self->{die_head} . "document node namespace declaration must be $NSURL (not $dm_ns_url)\n";
    }

    return $dm_ns->name;
}

package XML::DifferenceMarkup::Diff;

use XML::LibXML;
use Algorithm::Diff qw(traverse_balanced);

use strict;
use warnings;

use vars qw(@ISA);

@ISA = qw(XML::DifferenceMarkup::Target);

sub new {
    my ($class, $nsprefix, $nsurl) = @_;

    # warn "new\n";
    my $self = XML::DifferenceMarkup::Target::new($class, $nsurl);
    $self->{nsprefix} = $nsprefix;
    return $self;
}

sub diff_nodes {
    my ($self, $m, $n) = @_;

    $self->{dest} = XML::LibXML::Document->createDocument;
    $self->{dest_point} = $self->{dest}->createElementNS(
        $self->{nsurl},
        $self->get_scoped_name('diff'));
    $self->{dest}->setDocumentElement($self->{dest_point});

    if ($m->toString eq $n->toString) {
	my $copy = $self->{dest}->createElementNS(
            $self->{nsurl},
            $self->get_scoped_name('copy'));
	$self->{dest_point}->appendChild($copy);
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

sub _eq_shallow {
    my ($self, $m, $n) = @_;

    # warn "_eq_shallow\n";

    # 10Sep2002: this isn't really equality as understood by DOM (the
    # same attributes in different order will be considered
    # different), but it's the same equality as used in other places
    # (most importantly traverse_balanced)

    my $p = $self->get_tip($m);
    my $q = $self->get_tip($n);

    return $p->toString eq $q->toString;
}

# insert a bottom pair
sub _replace {
    my ($self, $m, $n) = @_;

    # warn "_replace\n";

    my $del = $self->{dest}->createElementNS(
        $self->{nsurl},
        $self->get_scoped_name('delete'));
    $self->{dest_point}->appendChild($del);

    $del->appendChild($self->import_tip($m));
    $self->_append_insert($n);
}

sub _append_insert {
    my ($self, $n) = @_;

    # warn "_append_insert(" . $self . ", " . $n->nodeName . ")\n";

    my $ins = $self->{dest}->createElementNS(
        $self->{nsurl},
        $self->get_scoped_name('insert'));
    $self->{dest_point}->appendChild($ins);
    $ins->appendChild($self->{dest}->importNode($n));
}

sub _append_delete {
    my ($self, $n) = @_;

    # warn "_append_delete(" . $self . ", " . $n->nodeName . ")\n";

    my $del = $self->{dest}->createElementNS(
        $self->{nsurl},
        $self->get_scoped_name('delete'));
    $self->{dest_point}->appendChild($del);
    $del->appendChild($self->{dest}->importNode($n));
}

sub _append_copy {
    my $self = shift;

    # warn "_append_copy($self)\n";

    my $copy = $self->{dest}->createElementNS(
        $self->{nsurl},
        $self->get_scoped_name('copy'));
    $self->{dest_point}->appendChild($copy);
    $copy->setAttribute('count', 1);
}

sub _descend {
    my ($self, $m, $n) = @_;

    # warn "_descend\n";

    my $seq = $self->import_tip($n);

    $self->{dest_point}->appendChild($seq);
    $self->{dest_point} = $seq;

    my $a = $self->_children($m);
    my $b = $self->_children($n);

    # 25Sep2002: From the Algorithm::Diff POD: "If both arrows point
    # to elements that are not part of the LCS, then
    # C<traverse_sequences> will advance one of them and call the
    # appropriate callback, but it is not specified which it will
    # call." That's a problem, because XML::DifferenceMarkup needs the
    # callbacks called in a very specific order, namely the order
    # minimizing the size of the resulting diff. Using
    # C<traverse_balanced> does not *guarantee* minimal diff, but
    # "jumping back and forth" between insertions & deletions seems
    # like a good heuristics...

    traverse_balanced($a, $b,
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
        $self->get_scoped_name('delete')) {
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

    my $dm = XML::DifferenceMarkup::Diff->new($self->{nsprefix},
        $self->{nsurl});
    my $dom = $dm->diff_nodes($m, $n);
    return $dom->documentElement;
}

# returns 1 the subtree of the child has been merged, 0 no merge
# possible
sub _combine_first_child {
    my ($self, $first_child, $checked_name) = @_;

    my $last = $self->{dest_point}->lastChild;
    if (!$last) {
	return 0;
    }

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

# returns 1 OK (destination has been modified), 0 it isn't possible to
# combine the pair (i.e. because one node of the pair is a text node)
sub _combine_pair {
    my ($self, $n, $reverse) = @_;

    # warn "_combine_pair(" . $self . ", " . $n->nodeName . ", " . $reverse . ")\n";

    my $last = $self->{dest_point}->lastChild;
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

    my $moved = $last->lastChild;
    # 14Sep2002: it is incorrect to check the equality of first & last
    # child using isSameNode - isSameNode checks structural (deep)
    # equivalence, *not* identity
    if (!$moved->previousSibling) {
	# the same node might be immediately created again, but that's
	# just inefficient, whereas leaving an empty insert/delete
	# node in the destination tree is downright incorrect
	$self->{dest_point}->removeChild($last);
    } else {
	$last->removeChild($moved);
    }

    if ($self->_combine_first_child($ch,
            $self->get_scoped_name('delete')) ||
	$self->_combine_first_child($ch,
            $self->get_scoped_name('insert'))) {
	$ch = $ch->nextSibling;
    }

    while ($ch) {
	$self->{dest_point}->appendChild($self->{dest}->importNode($ch));
	$ch = $ch->nextSibling;
    }

    return 1;
}

sub _on_insert {
    my ($self, $n) = @_;

    # warn "_on_insert(" . $self . ", " . $n->nodeName . ")\n";

    my $last = $self->{dest_point}->lastChild;
    if (!$last) {
	$self->_append_insert($n);
    } elsif ($last->nodeName eq $self->get_scoped_name('insert')) {
	$last->appendChild($self->{dest}->importNode($n));
    } elsif ($last->nodeName ne $self->get_scoped_name('delete')) {
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

    my $last = $self->{dest_point}->lastChild;
    if (!$last) {
	$self->_append_delete($n);
    } elsif ($last->nodeName eq $self->get_scoped_name('delete')) {
	# the last node under <delete/> isn't going to be descended
	# into (because it's going to be followed by another deleted
	# node); we can leave only the top node from it & remove the
	# subnodes
	$self->_prune($last);
	$last->appendChild($self->{dest}->importNode($n));
    } elsif ($last->nodeName ne $self->get_scoped_name('insert')) {
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
	$self->remove_children($ch);
	$ch = $ch->nextSibling;
    }
}

sub _on_match {
    my $self = shift;

    # warn "_on_match\n";

    my $last = $self->{dest_point}->lastChild;
    my $count;
    if (!$last) {
	$self->_append_copy;
    } elsif ($last->nodeName ne $self->get_scoped_name('copy')) {
	if ($last->nodeName eq $self->get_scoped_name('delete')) {
	    $self->_prune($last);
	}
	$self->_append_copy;
    } else {
	$count = 1 + $last->getAttribute('count');
	$last->setAttribute('count', $count);
    }
}

package XML::DifferenceMarkup::Target;

use strict;
use warnings;

sub new {
    my ($class, $nsurl) = @_;

    my $self = { nsurl => $nsurl };
    # also using nsprefix & dest, but those are initialized later

    return bless $self, $class;
}

# copy a node to the destination tree, removing its children in the
# process
sub import_tip {
    my ($self, $n) = @_;

    my $tip = $self->get_tip($n);
    return $self->{dest}->importNode($tip);
}

# get (a copy of) a node without its chidren (note that the result is
# different than cloneNode(0) - the attributes are kept)
sub get_tip {
    my ($self, $n) = @_;

    my $tip = $n->cloneNode(1);
    $self->remove_children($tip);
    return $tip;
}

sub remove_children {
    my ($dummy, $n) = @_;

    # warn "remove_children\n";

    my $ch = $n->firstChild;
    while ($ch) {
	my $next = $ch->nextSibling;
	$n->removeChild($ch);
	$ch = $next;
    }
}

sub get_scoped_name {
    my ($self, $tail) = @_;

    return $self->{nsprefix} . ":$tail";
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
	    die "XML::DifferenceMarkup diff: input tree contains the reserved namespace " . $self->{nsurl} . "\n";
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
	    die "XML::DifferenceMarkup diff: invalid XML: no namespace declaration for prefix " .
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
