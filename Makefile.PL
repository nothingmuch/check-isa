#!/usr/bin/perl -w

use strict;

use ExtUtils::MakeMaker;

require 5.008;

WriteMakefile(
	NAME         => 'Check::ISA',
	VERSION_FROM => 'lib/Check/ISA.pm',
	INSTALLDIRS  => 'site',
	SIGN         => 1,
	PL_FILES     => { },
	PREREQ_PM    => {
		'Test::use::ok' => 0,
		'Sub::Exporter' => 0,
		'XSLoader'      => 0,
	},
);

