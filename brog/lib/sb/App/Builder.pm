# sb::App::Builder - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::App::Builder;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.05';
# 0.05 [2005/08/23] changed _build_files to build correctly when number of article is below max number of building
# 0.04 [2005/08/23] changed _check_mode to check session correctly
# 0.03 [2005/08/05] chnaged _build_files to build all files correctly
# 0.02 [2005/07/24] changed _build_files to check whether xml request is acceptable or not
# 0.01 [2005/07/22] changed _build_file to allow to build multiple files at once
# 0.00 [2005/07/18] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Build ();
use sb::Data ();
use sb::Time ();
use sb::Lock ();
use sb::Interface ();
use sb::Config ();
use sb::App ();
@ISA = qw( sb::App );
# ==================================================
# // declaration for constant value
# ==================================================
sub COOKIE_USER (){ 'user' };
# ==================================================
# // public functions - main routine
# ==================================================
sub run { # main routine for builder
	my $class = shift;
	my $self  = $class->SUPER::new( @_ );
	my $cgi   = sb::Interface->get;
	my $error = $self->_check_mode($cgi->cookie('name'=>sb::Config->get->value('basic_admntag') . COOKIE_USER));
	if (!$error) {
		my $lock = sb::Lock->lock;
		$error = ($lock) ? $self->_build_files(int($cgi->value('__rebuild'))) : 'fail to lock';
		$lock->unlock if ($lock);
	}
	print $cgi->head('type'=>'text/xml','charset'=>'UTF-8');
	print '<?xml version="1.0"?>',"\n",'<result>',$error,'</result>',"\n";
}
# ==================================================
# // private functions
# ==================================================
sub _check_mode { # checking session and user
	my $self = shift;
	my $cook = shift;
	my $conf = sb::Config->get;
	return( 'wrong user' ) if ($cook->{'user'} eq '');
	foreach my $user ( sb::Data->load('User') ) {
		next if ($user->name ne $cook->{'user'});
		my $session = sb::Session->new(
			'time'   => $self->{'time'},
			'key'    => $user->id,
			'path'   => $conf->value('conf_srv_cgi') . $conf->value('basic_admn'),
			'name'   => $conf->value('basic_sessiontag'),
			'expire' => $conf->value('basic_admn_expire'),
		);
		return( 'session expires' ) if ( !$session->check );
	}
	return( undef );
}
sub _build_files { # rebuild files
	my $self = shift;
	my $num  = shift;
	my $type = sb::Config->get->value('conf_entry_archive');
	my %cats = sb::Data->load_as_hash('Category');
	my $builder = sb::Build->new(
		'time'      => $self->{'time'},
		'user'      => { sb::Data->load_as_hash('User') },
		'cat'       => \%cats,
		'sortedcat' => [ sort { $b->order <=> $a->order } values(%cats) ],
		'blog'      => sb::Data->load('Weblog','id'=>0),
	);
	$builder->set_entryinfo;
	if ($num == 0) {
		foreach my $cat ( values(%cats) ) { # category indexes
			next if (!$cat->idx);
			next if ($cat->dir eq '');
			$builder->build_category_index($cat->id);
		}
		$builder->set_latest_entries;
		$builder->build_top_page;
		$builder->build_feedfile('all');
		$builder->build_javascript('all') if ($type eq 'Individual');
		$builder->build_css;
		$builder->build_cookie_js('force_to_create');
		return ($type eq 'None') ? 'completed' : 1;
	} elsif ($num > 0) {
		my $now = undef;
		my $nxt = undef;
		if ($type eq 'Individual') {
			$num--;
			my $max = sb::Config->get->value('basic_build_ajax');
			my @entries = sb::Data->load('Entry',
				'cond'   => {'stat'=>[1,2]},
				'sort'   => 'date',
				'order'  => 1,
				'num'    => $max + 2,
				'bgn'    => ($num > 0) ? ($num * $max - 1) : 0,
				'detail' => 'on',
			);
			my $bgn = ($num > 0) ? 1 : 0;
			my $end = @entries;
			if ($end > $max and $num =~ /^\d+$/) {
				$end = $max if ($num == 0);
				$end = $max + 1 if ($end > $max + 1);
			}
			for (my $i=$bgn;$i<$end;$i++) {
				my $nxt_ent = ($i > 0)         ? $entries[$i - 1] : undef;
				my $prv_ent = ($i < $#entries) ? $entries[$i + 1] : undef;
				$builder->build_entry($entries[$i],'prev'=>$prv_ent,'next'=>$nxt_ent);
			}
			$now = $entries[$end - 1];
			$nxt = $entries[$end];
		} elsif ($type eq 'Monthly') {
			my @entries = sb::Data->load('Entry','sort'=>'date','order'=>1,'cond'=>{'stat'=>[1,2]});
			my %check = ();
			for (my $i=0;$i<@entries;$i++) {
				my $month = sb::Time->format(
					'time'=>$entries[$i]->date,
					'form'=>'%Year%%Mon%',
					'zone'=>$entries[$i]->tz
				);
				$check{$month} = $month if ( !defined($check{$month}) );
			}
			my @monthly = sort { $b <=> $a } keys(%check);
			$now = $monthly[ $num - 1 ];
			$nxt = $monthly[ $num ];
			$builder->build_monthly_archive($now) if ($now);
		}
		if ($now) {
			return ($nxt) ? 1 : 'completed';
		} else {
			return 'no entry';
		}
	} else { # $num < 0
		return 1;
	}
}
1;
__END__
