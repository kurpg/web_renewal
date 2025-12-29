# sb::Time - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Time;

use strict;

# ==================================================
# // Module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.03';
# 0.03 [2005/10/20] changed _format to add %Zone%
# 0.02 [2005/02/08] defined input parameter as hash
# 0.01 [2005/02/01] move into util
# 0.00 [2004/11/20] porting from sbtime.pl

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use Time::Local;
use sb::Language ();
# ==================================================
# // public functions
# ==================================================
sub format { # time format module
	my $class = shift;
	my %param = (
		'time' => undef,   # Unix Time
		'form' => '',      # Format
		'zone' => '+0000', # default time zone
		'lang' => 'en',    # default language code
		@_,
	);
	return( &_format( %param ) );
}
sub convert { # convert time from array
	my $class = shift;
	my %param = (
		'year' => 0,
		'mon'  => 0,
		'day'  => 1,
		'hour' => 0,
		'min'  => 0,
		'sec'  => 0,
		'zone' => '+0000',
		@_,
	);
	$param{'year'} = int($param{'year'}) - 1900;
	$param{'mon'}  = int($param{'mon'}) - 1;
	$param{'zone'} = &_zone($param{'zone'});
	return( timegm($param{'sec'},$param{'min'},$param{'hour'},$param{'day'},$param{'mon'},$param{'year'}) - $param{'zone'} );
}
sub get_weekday { # get week day (programed by OHZAKI Hiroki)
	my $class = shift;
	my %param = ('year'=>1970,'mon'=>1,'day'=>1,@_);
	if ($param{'mon'} == 1 or $param{'mon'} == 2) {
		$param{'year'}--;
		$param{'mon'} += 12;
	}
	int($param{'year'} + int($param{'year'} / 4) - int($param{'year'} / 100) + int($param{'year'} / 400)
	+ int((13 * $param{'mon'} + 8) / 5) + $param{'day'}) % 7;
}
sub get_lastday { # get last day (programed by OHZAKI Hiroki)
	my $class = shift;
	my %param = ('year'=>1970,'mon'=>1,@_);
	return (
		(31,28,31,30,31,30,31,31,30,31,30,31)[$param{'mon'} - 1] 
		+ (($param{'mon'} == 2) and &_leapcheck($param{'year'}))
	);
}
sub diff_timezone {
	my $class = shift;
	my ($zone1,$zone2) = @_;
	return &_zone($zone1) - &_zone($zone2);
}
# ==================================================
# // private functions
# ==================================================
sub _format {
	my %param = @_;
	my $output = $param{'form'};
	my $zone = &_zone($param{'zone'}); # time zone
	my $lang = sb::Language->get(); # get a language instance
	if ($param{'time'} and $param{'form'}) {
		my ($se,$mi,$ho,$md,$mo,$ye,$wd,$yd,$is) = gmtime($param{'time'} + $zone);
		if (index($output,'%Year') > -1) { # Year
			my $tmp = $ye += 1900;
			$output =~ s/%YearLong%/$tmp/g;
			$output =~ s/%Year%/$tmp/g;
			$tmp = &_pad0($ye % 100);
			$output =~ s/%YearShort%/$tmp/g;
		}
		if (index($output,'%Mon') > -1) { # Month
			my $tmp = &_pad0($mo + 1);
			$tmp = $lang->string('month_' . $param{'lang'})->[$mo] if (ref($lang->string('month_' . $param{'lang'})) eq 'ARRAY');
			$output =~ s/%MonShort%/$tmp/g;
			$tmp = $lang->string('month_' . $param{'lang'} . 'long')->[$mo] if (ref($lang->string('month_' . $param{'lang'} . 'long')) eq 'ARRAY');
			$output =~ s/%MonLong%/$tmp/g;
			$tmp = $mo + 1;
			$output =~ s/%MonNumShort%/$tmp/g;
			$output =~ s/%MonNum%/$tmp/g;
			$tmp = &_pad0($mo + 1);
			$output =~ s/%MonNumLong%/$tmp/g;
			$output =~ s/%MonNumPad%/$tmp/g;
			$output =~ s/%Mon%/$tmp/g;
		}
		if (index($output,'%Day') > -1) { # Day
			my $tmp = $md . &_nsuf($md);
			$output =~ s/%DayOrd%/$tmp/g;
			$tmp = $md;
			$output =~ s/%DayShort%/$tmp/g;
			$tmp = &_pad0($md);
			$output =~ s/%DayLong%/$tmp/g;
			$output =~ s/%DayPad%/$tmp/g;
			$output =~ s/%Day%/$tmp/g;
		}
		if (index($output,'%Week') > -1) { # Week
			my $tmp = '';
			$tmp = $lang->string('week_' . $param{'lang'})->[$wd] if ( ref($lang->string('week_' . $param{'lang'})) eq 'ARRAY' );
			$output =~ s/%WeekShort%/$tmp/g;
			$output =~ s/%Week%/$tmp/g;
			$tmp = $lang->string('week_' . $param{'lang'} . 'long')->[$wd] if ( ref($lang->string('week_' . $param{'lang'} . 'long')) eq 'ARRAY' );
			$output =~ s/%WeekLong%/$tmp/g;
		}
		if (index($output,'%Hour') > -1) { # Hour
			my $tmp = ($ho < 12) ? &_pad0($ho) : &_pad0($ho - 12);
			$output =~ s/%Hour11%/$tmp/g;
			$tmp = 12 if ($tmp == 0);
			$output =~ s/%Hour12%/$tmp/g;
			$tmp = &_pad0($ho);
			$output =~ s/%Hour%/$tmp/g;
			$tmp = $ho;
			$output =~ s/%Hour24%/$tmp/g;
			$tmp = ($ho < 12) ? 'AM' : 'PM';
			$output =~ s/%HourAP%/$tmp/g;
		}
		if (index($output,'%Min') > -1) { # Minute
			my $tmp = &_pad0($mi);
			$output =~ s/%Min%/$tmp/g;
		}
		if (index($output,'%Sec') > -1) { # Second
			my $tmp = &_pad0($se);
			$output =~ s/%Sec%/$tmp/g;
		}
		if (index($output,'%Zone') > -1) { # Time Zone
			my $tmp = $param{'zone'};
			$output =~ s/%Zone%/$tmp/g;
		}
	}
	return($output);
}
sub _zone { # converting time zone
	return( ($1 eq '-') ? -3600 * $2 - 60 * $3 : 3600 * $2 + 60 * $3 ) if ($_[0] =~ /^([\+-])(\d\d)(\d\d)/);
	return(0);
}
sub _nsuf { # suffix for ordinal number
	return('st') if ( ($_[0] % 10) == 1 and $_[0] != 11 );
	return('nd') if ( ($_[0] % 10) == 2 and $_[0] != 12 );
	return('rd') if ( ($_[0] % 10) == 3 and $_[0] != 13 );
	return('th');
}
sub _pad0 { # padding 0
	return( ($_[0] < 10) ? '0' . $_[0] : $_[0] );
}
sub _leapcheck {
	return($_[0] % 4 == 0 and ($_[0] % 400 == 0 or $_[0] % 100 != 0));
}
1;
__END__
=head1 NAME

sb::Time - time format module for sb

=head1 SYNOPSIS

	use sb::Time;
	my $format = '%Week%, %DayShort%-%MonShort%-%YearLong% %Hour24%:%Min%:%Sec% GMT'; # for Cookie
	my $formated_text = sb::Time->format('time'=>time(),'form'=>$format);

=head1 DESCRIPTION

[time format module]
sb::Time returns formated text from UnixTime.

[input paramaeters]
'time' => UnixTime,      ex) time()
'form' => Format,        ex) '%Year%/%Mon%/%Day% %Hour%:%Min%:%Sec'
'zone' => Time Zone,     ex) +0900 [\-+](\d\d)(\d\d)
'lang' => Language Code, ex) 'en','ja' and so on

[format symbols]
old : description             : symbol                               :example
----:-------------------------:--------------------------------------:--------
%yr : A.D. 4 digits           : %Year% or %YearLong%                 :2005
%Yr : A.D. 2 dgits            : %YearShort%                          :05
%mo : Month 2 digits          : %Mon% or %MonNumLong% or %MonNumPad% :02
%MO : Month Short Name [lang] : %MonShort%                           :Feb.
%mO : Month Long Name [lang]  : %MonLong%                            :February
%Mo : Month (Number)          : %MonNumShort% or %MonNum%            :2
%dy : Day 2 digits            : %Day% or %DayLong% or %DayPad%       :01
%DY : Day (Ordinal number)    : %DayOrd%                             :1st
%Dy : Day                     : %DayShort%                           :1
%wk : Day of week [lang]      : %Week% or %WeekShort%                :Tue
%Wk : Day of week (long)[lang]: %WeekLong%                           :Tuesday
%hr : Hour 2 digits           : %Hour%                               :00
    : Hour (24 hours)         : %Hour24%                             :0
%Hr : Hour (0-11 hours)       : %Hour11%                             :00
%hR : Hour (1-12 hours)       : %Hour12%                             :12
%HR : AM/PM                   : %HourAP%                             :AM
%mi : Minute 2 digits         : %Min%                                :01
%sc : Second 2 digits         : %Sec%                                :02
    : Timezone                : %Zone%                               :+0900

[note]
Old symbols such as %yr, %mo and so on are NOT used anymore.
[lang] in description means output string depends on language.

=head1 AUTHOR

Takuya Otani http://serenebach.net/

=head1 LICENSE

Copyright (C) 2004- T.Otani@SimpleBoxes and SerendipityNZ

=cut
