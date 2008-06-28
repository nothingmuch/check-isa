#!/usr/bin/perl

package Check::ISA;

use strict;
use warnings;

use Scalar::Util qw(blessed);

use Sub::Exporter -setup => {
	exports => [qw(obj inv obj_can inv_can)],
	groups => {
		default => [qw(obj inv)],
	},
};

use constant CAN_HAS_DOES => not not UNIVERSAL->can("DOES");

use warnings::register;

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
	my ( $object_or_filehandle, $class_or_role ) = @_;

	my $object = blessed($object_or_filehandle)
		? $object_or_filehandle
		: extract_io($object_or_filehandle) || return;

	if ( defined $class_or_role ) {
		return CAN_HAS_DOES
			? $object->DOES($class_or_role)
			: $object->isa($class_or_role)
	} else {
		return 1; # return $object? what if it's overloaded?
	}
}

sub inv ($;$) {
	my ( $inv, $class_or_role ) = @_;

	if ( blessed($inv) ) {
		return obj($inv, $class_or_role);
	} else {
		if ( !ref($inv) and $inv ) {
			$class_or_role = "UNIVERSAL" unless defined $class_or_role;

			local $@;
			return eval {
				return CAN_HAS_DOES
					? $inv->DOES($class_or_role)
					: $inv->isa($class_or_role)
			}
		} else {
			return;
		}
	}
}

sub obj_can {
	my ( $obj, $method ) = @_;
	(blessed($obj) ? $obj : extract_io($obj) || return)->can($method);
}

sub inv_can {
	my ( $inv, $method ) = @_;
	obj_can($inv, $method) || inv($inv) && $inv->can($method);
}


__PACKAGE__

__END__

=pod

=head1 NAME

Check::ISA - DWIM checking of object class

=head1 SYNOPSIS

	use Check::ISA;

	if ( obj($foo, "SomeClass") ) {
		$foo->some_method;
	}

	# instead of:

	UNIVERSAL::isa($foo, "SomeClass") # WRONG
	$foo->isa("SomeClass") # May die
	local $@; eval { $foo->isa("SomeClass") } # too long

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item obj $thing, [ $class_or_role ]

This function tests if C<$thing> is an object, and if C<$class_or_role> is
supplied, tests whether C<< $thing->DOES($class_or_role) >>. L<UNIVERSAL/DOES>
is just like C<isa>, except it's use is encouraged to query about an interface,
as opposed to the object structure.

C<$thing> is considered an object if it's blessed, or if it's a C<GLOB> with a
valid C<IO> slot (this is a L<FileHandle> object).

=item inv $thing, [ $class_or_role ]

Just like C<obj>, but also returns true for classes.

=item obj_can $thing, $method

=item inv_can $thing, $method

Checks if C<$thing> is an object or class, and calls C<can> on C<$thing> if
appropriate.

=back

=cut


