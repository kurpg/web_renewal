#!/usr/bin/perl

use strict;
use lib qw(. ./lib);
use CGI::Carp qw(fatalsToBrowser);
use sb::Data::User ();

print "Content-Type: text/plain\n\n";

foreach my $key (sort keys %ENV) {
print "$key = $ENV{$key}\n";
}

print "\n";
$,="\n";
print @INC;
print "\n";

my $class = 'sb::Data::User';
my $dir = './data/user/';
my @array = ();
opendir(DATADIR, $dir);
my @file_list = readdir(DATADIR);

print @file_list;

closedir(DATADIR);
foreach my $file_name (@file_list)
{
	print "file: $file_name\n";
	next if ($file_name !~ /^(\d+)\./);
	my $file = $dir . $file_name;
	open(DATAIN,"<$file");
	my @data = &_decode(<DATAIN>);
#	my $obj = $class->alloc();
#	map { $obj->{$_} = shift(@data) } ['id'];
	close(DATAIN);
#	next if ( &{$func}($obj) );
#	push(@array,$obj);
}

print "\n";

print @array;

sub _decode
{
	my $line = shift;
	$line =~ tr/\x0D\x0A//d;
	return map { s/\\(.)/$1 eq 't' and "\t" or $1 eq 'n' and "\n" or "$1"/eg; $_; } split("\t",$line);
}

exit(0);