#!/usr/bin/perl

package Check::ISA;

use strict;
use warnings;

use Scalar::Util qw(blessed);

use Sub::Exporter -setup => {
	exports => [qw(obj obj_does inv inv_does obj_can inv_can)],
	groups => {
		default => [qw(obj obj_does inv)],
	},
};

use constant CAN_HAS_DOES => not not UNIVERSAL->can("DOES");

use warnings::register;

our $VERSION = "0.04";

sub extract_io {
	my $glob = shift;

	# handle the case of a string like "STDIN"
	# STDIN->print is actually:
	#   const(PV "STDIN") sM/BARE
	#   method_named(PV "print")
	# so we need to lookup the glob
	if ( defined($glob) and !ref($glob) and length($glob) ) {
		no strict 'refs';
		$glob = \*{$glob};
	}

	# extract the IO
	if ( ref($glob) eq 'GLOB' ) {
		if ( defined ( my $io = *{$glob}{IO} ) ) {
			require IO::Handle;
			return $io;
		}
	}

	return;
}

sub obj ($;$); # predeclare, it's recursive

sub obj ($;$) {
	my ( $object_or_filehandle, $class ) = @_;

	my $object = blessed($object_or_filehandle)
		? $object_or_filehandle
		: extract_io($object_or_filehandle) || return;

	if ( defined $class ) {
		$object->isa($class)
	} else {
		return 1; # return $object? what if it's overloaded?
	}
}

sub obj_does ($;$) {
	my ( $object_or_filehandle, $class_or_role ) = @_;

	my $object = blessed($object_or_filehandle)
		? $object_or_filehandle
		: extract_io($object_or_filehandle) || return;

	if ( defined $class_or_role ) {
		if ( CAN_HAS_DOES ) {
			# we can be faster in 5.10
			$object->DOES($class_or_role);
		} else {
			my $method = $object->can("DOES") || "isa";
			$object->$method($class_or_role);
		}
	} else {
		return 1; # return $object? what if it's overloaded?
	}
}

sub inv ($;$) {
	my ( $inv, $class_or_role ) = @_;

	if ( blessed($inv) ) {
		return obj_does($inv, $class_or_role);
	} else {
		# we check just for scalar keys on the stash because:
		# sub Foo::Bar::gorch {}
		# Foo->can("isa") # true
		# Bar->can("isa") # false
		# this means that 'Foo' is a valid invocant, but Bar is not

		if ( !ref($inv)
				and
			defined $inv
				and
			length($inv)
				and
			do { no strict 'refs'; scalar keys %{$inv . "::"} }
		) {
			# it's considered a class name as far as gv_fetchmethod is concerned
			# even if the class def is empty
			if ( defined $class_or_role ) {
				if ( CAN_HAS_DOES ) {
					# we can be faster in 5.10
					$inv->DOES($class_or_role);
				} else {
					my $method = $inv->can("DOES") || "isa";
					$inv->$method($class_or_role);
				}
			} else {
				return 1; # $inv is always true, so not a problem, but that would be inconsistent
			}
		} else {
			return;
		}
	}
}

sub obj_can ($;$) {
	my ( $obj, $method ) = @_;
	(blessed($obj) ? $obj : extract_io($obj) || return)->can($method);
}

sub inv_can ($;$) {
	my ( $inv, $method ) = @_;
	obj_can($inv, $method) || inv($inv) && $inv->can($method);
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

