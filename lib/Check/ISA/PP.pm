#!/usr/bin/perl

package Check::ISA;

use strict;
use warnings;

use constant CAN_HAS_DOES => not not UNIVERSAL->can("DOES");

use Scalar::Util qw(blessed);

sub _extract_io {
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
		: _extract_io($object_or_filehandle) || return;

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
		: _extract_io($object_or_filehandle) || return;

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

sub obj_can ($$) {
	my ( $obj, $method ) = @_;
	(blessed($obj) ? $obj : _extract_io($obj) || return)->can($method);
}

sub inv_can ($$) {
	my ( $inv, $method ) = @_;
	obj_can($inv, $method) || inv($inv) && $inv->can($method);
}

__PACKAGE__
