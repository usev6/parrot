#!perl
use warnings;
use strict;

=pod

Temporary helper script for generating vtable.pm

Invoke
"perl -Ilib compilers/pmc/tools/vtable_pm.pl > compilers/pmc/src/vtable_info.pm"

=cut

use Parrot::Vtable;

my $vtable = parse_vtable;

print <<'HEADER';
# $Id$
#
# DO NOT EDIT THIS FILE. Generated from src/vtable.pl by
# compilers/pmc/tool/vtable_pm.pl
#
# In future this file will be replaced by full featured PCT parser for
# src/vtable.tbl
#

class PMC::VTableInfo;

# Ordered list of VTable methods
our @?VTABLES := build_vtable_list();
our %?VTABLES := build_vtable_hash();

HEADER


print "sub build_vtable_list() {\n    my \@res;\n";

foreach (@$vtable) {
    my $is_write = int exists $_->[5]{write};
    print <<"VTABLE"
    \@res.push(PMC::VTableInfo.new(
        :ret_type('$_->[0]'),
        :name('$_->[1]'),
        :parameters('$_->[2]'),
        :is_write($is_write)
   ));

VTABLE
}

print "\n    \@res;\n}\n";

print <<'FOOTER';

# Generate hash from list
sub build_vtable_hash() {
    my %res;
    our @?VTABLES;
    for (@?VTABLES) {
        my $name    := $_.name;
        %res{$name} := $_;
    }
    %res;
}

sub vtable_list() {
    our @?VTABLES;
    @?VTABLES;
}

sub vtable_hash() {
    our %?VTABLES;
    %?VTABLES;
}

# Local Variables:
#   mode: perl6
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4:
FOOTER
