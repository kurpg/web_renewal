# sb::App::Counter - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::App::Counter;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.04';
# 0.04 [2006/11/12] changed _update_count to fix a bug
# 0.03 [2005/08/11] changed _update_count to name log file with extension
# 0.02 [2005/07/10] changed _update_count to check existance of a file correctly
# 0.01 [2005/07/06] added entry point for plugin
# 0.00 [2004/02/01] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Plugin ();
use sb::Lock ();
use sb::Time ();
use sb::Text ();
use sb::App ();
@ISA = qw( sb::App );
# ==================================================
# // declaration for constant value
# ==================================================
sub SECS_PER_MIN (){ 60 };
# ==================================================
# // public functions
# ==================================================
sub run {
	my $class = shift;
	my $self  = $class->SUPER::new( @_ );
	my $cgi   = sb::Interface->get;
	my @funcs = sb::Plugin->load_extra_module('counter');
	if (@funcs) {
		foreach my $func (@funcs) {
			eval{ &$func($self); };
		}
	} else {
		my $mode = ($cgi->value('disp') eq 'on') ? 'script' : 'image';
		print $cgi->head(
			'type'  => ($mode eq 'script') ? 'text/javascript' : 'image/gif',
			'cache' => $self->{'time'} - 100,
		);
		$self->_display_count if ($mode eq 'script');
		$self->_update_count  if ($mode eq 'image');
	}
}
# ==================================================
# // private functions - main routine
# ==================================================
sub _display_count {
	my $self = shift;
	my $text = sprintf('document.write("%d");',$self->_load_count);
	print $text,"\n";
}
sub _update_count {
	my $self = shift;
	my $conf = sb::Config->get;
	my $cgi  = sb::Interface->get;
	my $cook = $cgi->cookie('name'=>$conf->value('basic_logtag'));
	my $date = sb::Time->format('time'=>$self->{'time'},'form'=>'%Year%%Mon%%Day%');
	my $lock = sb::Lock->lock('basename'=>$conf->value('file_lckcnt'));
	my $dir  = $conf->value('dir_data');
	my $update = undef;
	my ($count,$ip,$access);
	my %env = ();
	$env{'host'} = $cgi->value('_host');
	$env{'addr'} = $cgi->value('_addr');
	$env{'refe'} = $cgi->value('_refe');
	$env{'agnt'} = $cgi->value('_agnt');
	$env{'href'} = $cgi->value('href');
	$env{'quer'} = $cgi->value('refe');
	foreach my $key ( keys(%env) ) {
		$env{$key} =~ s/\\/\\\\/g;
		$env{$key} =~ s/\t/\\t/g;
		$env{$key} =~ s/\n/\\n/g;
	}
	# load and save counter
	my $lfh = sb::Lock->locked_open($dir . $conf->value('file_access'),'without_truncate');
	if ($lfh) {
		my $line  = <$lfh>;
		($count,$ip,$access) = split("\t",$line); # count/ip/time
		$count = int($count); # to make sure $count is integer variable.
		$count++ if ($env{'addr'} ne $ip and $cook->{'check'} ne $conf->value('basic_cookiekey'));
		if ($conf->value('basic_min_update') == 0) {
			$access = $self->{'time'};
		} elsif ($self->{'time'} - $access > $conf->value('basic_min_update') * SECS_PER_MIN) {
			$access = $self->{'time'};
			$update = 1;
		}
		truncate($lfh, 0);
		seek($lfh, 0, 0);
		print $lfh $count,"\t",$env{'addr'},"\t",$access,"\n";
		close($lfh);
	}
	# store log data
	my $file = $dir . $conf->value('dir_access') . $date . $conf->value('file_suf');
	my $flag = (-e $file) ? open(ACCESSLOG,">>$file") : open(ACCESSLOG,">$file");
	if ($flag and $cook->{'check'} ne $conf->value('basic_cookiekey')) {
		print ACCESSLOG $self->{'time'},"\t";
		print ACCESSLOG $env{'addr'},"\t";
		print ACCESSLOG $env{'host'},"\t";
		print ACCESSLOG $env{'refe'},"\t";
		print ACCESSLOG $env{'agnt'},"\t";
		print ACCESSLOG $env{'href'},"\t";
		print ACCESSLOG $env{'quer'},"\t","\n";
		close(ACCESSLOG);
		chmod($conf->value('basic_file_attr'),$file);
	}
	# trigger updating weblog
	$self->_update_weblog if ($update);
	$lock->unlock if ($lock);
	&_display_blank();
}
sub _update_weblog {
	my $self = shift;
	# [TODO] automatic updating weblog function
}
# ==================================================
# // private functions - utilities
# ==================================================
sub _load_count {
	my $self = shift;
	my $file = sb::Config->get->value('dir_data') . sb::Config->get->value('file_access');
	open(TOTALIN,"<$file");
	my $count = <TOTALIN>;
	close(TOTALIN);
	return( int($count) );
}
sub _display_blank {
	my @aDummy = (
		'47','49','46','38','39','61','02','00','02','00','80','00','00','00','00',
		'00','ff','ff','ff','21','f9','04','01','00','00','01','00','2c','00','00',
		'00','00','02','00','02','00','00','02','02','8c','53','00','3b'
	);
	binmode(STDOUT);
	foreach (@aDummy) {
		print pack('C*',hex($_));
	}
	return();
}
1;
__END__
