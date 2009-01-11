#!/usr/bin/perl

package Check::ISA;

use strict;
use warnings;

use IO::Handle;

use Sub::Exporter -setup => {
	exports => [qw(obj obj_does inv inv_does obj_can inv_can)],
	groups => {
		default => [qw(obj obj_does inv)],
	},
};

use warnings::register;

BEGIN {
	our $VERSION = "0.04";

    my $e = do {
        local $@;
        eval {
            require XSLoader;
            # just doing this - no warnings 'redefine' - doesn't work
            # for some reason
            local $^W = 0;
            __PACKAGE__->XSLoader::load($VERSION);
        };

        $@;
    };

    if ( $e ) {
		die $e if $e !~ /object version|loadable object/;
		require Check::ISA::PP;
	}
}

__PACKAGE__

__END__

=pod

=head1 NAME

Check::ISA - DWIM, correct checking of an object's class

=head1 SYNOPSIS

	use Check::ISA;

	if ( obj($foo, "SomeClass") ) {
		$foo->some_method;
	}


	# instead of one of these methods:
	UNIVERSAL::isa($foo, "SomeClass") # WRONG
	ref $obj eq "SomeClass"; # VERY WRONG
	$foo->isa("SomeClass") # May die
	local $@; eval { $foo->isa("SomeClass") } # too long

=head1 DESCRIPTION

This module provides several functions to assist in testing whether a value is
an object, and if so asking about its class.

=head1 FUNCTIONS

=over 4

=item obj $thing, [ $class ]

This function tests if C<$thing> is an object.

If C<$class> is provided, it also tests tests whether
C<< $thing->isa($class) >>.

C<$thing> is considered an object if it's blessed, or if it's a C<GLOB> with a
valid C<IO> slot (the C<IO> slot contains a L<FileHandle> object which is the
actual invocant). This corresponds directly to C<gv_fetchmethod>.

=item obj_does $thing, [ $class_or_role ]

Just like C<obj> but uses L<UNIVERSAL/DOES> instead of L<UNIVERSAL/isa>.

L<UNIVERSAL/DOES> is just like C<isa>, except it's use is encouraged to query
about an interface, as opposed to the object structure. If C<DOES> is not
overridden by th ebject, calling it is semantically identical to calling
C<isa>.

This is probably reccomended over C<obj> for interoperability, but can be
slower on Perls before 5.10.

Note that L<UNIVERSAL/DOES>

=item inv $thing, [ $class_or_role ]

Just like C<obj_does>, but also returns true for classes.

Note that this method is slower, but is supposed to return true for any value
you can call methods on (class, object, filehandle, etc).

Look into L<autobox> if you would like to be able to call methods on all
values.

=item obj_can $thing, $method

=item inv_can $thing, $method

Checks if C<$thing> is an object or class, and calls C<can> on C<$thing> if
appropriate.

=back

=head1 SEE ALSO

L<UNIVERSAL>, L<Params::Util>, L<autobox>, L<Moose>, L<asa>

=head1 VERSION CONTROL

This module is maintained using Darcs. You can get the latest version from
L<http://nothingmuch.woobling.org/code>, and use C<darcs send> to commit
changes.

=head1 AUTHOR

Yuval Kogman E<lt>nothingmuch@woobling.orgE<gt>

=head1 COPYRIGHT

	Copyright (c) 2008 Yuval Kogman. All rights reserved
	This program is free software; you can redistribute
	it and/or modify it under the same terms as Perl itself.

=cut

