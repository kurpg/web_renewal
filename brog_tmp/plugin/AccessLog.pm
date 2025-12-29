#!/usr/bin/perl -w
# 
# sb::Plugin::AccessLog - Module for sb
# == written by T.Otani <ootani@segausers.gr.jp> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

# 0.05 [2006/08/03] changed detail to point new site address
# 0.04 [2005/08/11] changed _load_logfile to load log correctly
# 0.03 [2005/07/30] changed NOSCRIPT_FORMAT and _script_template
# 0.02 [2005/07/20] changed _analyze_log to handle log for references correctly

package sb::Plugin::AccessLog;
# ==================================================
# // initialization for plugin
# ==================================================
use sb::Plugin ();
# register this plugin
sb::Plugin->register_plugin(
	'lang' => {
		'ja' => 'euc',
		'en' => 'ascii',
	},
	'text' => {
		'type'    => 'admin, cms',
		'name'    => 'Access Log',
		'text'    => 'Displaying access log of your weblog.',
		'author'  => 'takkyun',
		'detail'  => 'http://serenebach.net/',
		'version' => '0.05',
	},
	'file' => 'accesslog.txt',
	'data' => 1,
);
# register as admin module
sb::Plugin->register_admin_module(
	'mode'   => 'accesslog',
	'level'  => 1,
	'module' => 'sb::Admin::AccessLog',
);
# register as cms module
sb::Plugin->register_content_module(
	'type'     => 'main',
	'callback' => \&sb::Content::AccessLog::_log_collector,
	'field'    => 'counter',
);
package sb::Content::AccessLog;
# ==================================================
# // functions for content
# ==================================================
sub SCRIPT_FORMAT   (){ '<script type="text/javascript" src="%s"></script>' };
sub NOSCRIPT_FORMAT (){ '<noscript><div class="accesslog"><img src="%s" width="1" height="1" alt="" /></div></noscript>' };
sub _log_collector {
	my $cms = shift;
	my %var = @_;
	my $cgi = $var{'conf'}->value('conf_srv_cgi') . $var{'conf'}->value('basic_cnt');
	my $js  = $var{'conf'}->value('conf_srv_base') . $var{'conf'}->value('conf_dir_log') . $var{'conf'}->value('file_logjs');
	$cms->tag('show_counter'=>sprintf(SCRIPT_FORMAT,$cgi . '?disp=on'));
	$cms->tag('collect_log'=>sprintf(SCRIPT_FORMAT,$js) . sprintf(NOSCRIPT_FORMAT,$cgi));
	return(1);
}
package sb::Admin::AccessLog;
# ==================================================
# // declaration for global variables
# ==================================================
use vars qw( @ISA );
# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Language ();
use sb::Interface ();
use sb::TemplateManager ();
use sb::Text ();
use sb::Config ();
use sb::Lock ();
use sb::Admin::List ();
@ISA = qw( sb::Admin::List );
# ==================================================
# // declaration for constant value
# ==================================================
sub TEMPLATE        (){ 'accesslog.html' };
sub PARTS_BAR       (){ 'accesslog_bar.gif' };
sub BAR_MAX_H       (){ 300 };
sub BAR_MAX_W       (){ 300 };
sub DAYS_SIMPLE     (){ 7 };
sub MAXLOG_SIMPLE   (){ 30 };
sub LOG_MAXLENGTH   (){ 50 };
sub LOG_MAXLEN_AGNT (){ 100 };
sub DEFAULT_TYPE    (){ 'simple' };
sub DEFAULT_EXPIRES (){ 30 };
sub HOURS_PER_DAY   (){ 24 };
sub SECS_PER_HOUR   (){ 3600 };
# ==================================================
# // public functions - callback
# ==================================================
sub callback { # callbacks
	my $self = shift;
	return ( $self->{'regi'} ) 
		? $self->_save_setting(@_)
		: $self->_open_log(@_);
}
# ==================================================
# // private functions - main routine
# ==================================================
sub _save_setting {
	my $self = shift;
	my %param = ( 'message' => '', @_ );
	my $cgi  = sb::Interface->get;
	my $data = sb::Plugin->get_data;
	my $conf = sb::Config->get;
	if ($cgi->value('change_total') eq 'on') {
		my $num = int($cgi->value('total_access'));
		$num = 0 if ($num < 0);
		my $file = $conf->value('dir_data') . $conf->value('file_access');
		my $lfh  = sb::Lock->locked_open($file,'without_truncate');
		if ($lfh) {
			my $line = <$lfh>;
			my @check = split("\t",$line);
			$check[0] = $num;
			truncate($lfh, 0);
			seek($lfh, 0, 0);
			print $lfh $check[0],"\t",$check[1],"\t",$check[2],"\n";
			close($lfh);
		}
		chmod($conf->value('basic_file_attr'),$file);
	}
	my $days = int($cgi->value('log_days'));
	$days = 1 if ($days < 1);
	$conf->value('conf_checklog' => $days);
	$conf->store;
	return $self->_open_log('message'=>sb::Language->get->string('parts_confcomp'));
}
sub _open_log {
	my $self  = shift;
	my %param = ( 'message' => '', @_ );
	my $cms   = sb::TemplateManager->new(sb::Plugin->load_template('file'=>TEMPLATE));
	my $cgi   = sb::Interface->get;
	my $lang  = sb::Language->get;
	my $data  = sb::Plugin->get_data;
	my $type  = $cgi->value('__type') || DEFAULT_TYPE;
	my $lock  = sb::Lock->lock or die($lang->string('error_file_lock')) if (!$self->{'lock'});
	my @files = $self->_load_logfile('expire' => sb::Config->get->value('conf_checklog'));
	$lock->unlock if ($lock);
	if ($type ne 'setting') {
		my $barimg = sb::Plugin->get_resource_dir . PARTS_BAR;
		my %state = $self->_analyze_log($type,@files);
		if ($self->{'count'} > 0) { # daily report
			my @order = sort { $b cmp $a } keys( %{$state{'date'}} );
			my $num = 0;
			foreach my $elem ( @order ) {
				$cms->num($num);
				$cms->tag('sb_daylog_date'=>$elem);
				$cms->tag('sb_daylog_bar'=>int( $state{'date'}{$elem} * BAR_MAX_W / $self->{'count'}));
				$cms->tag('sb_daylog_num'=>$state{'date'}{$elem});
				$cms->tag('sb_access_bar'=>$barimg);
				$cms->tag('sb_list_class'=>($num % 2) ? 'odd' : 'even');
				$num++;
				last if ($type eq 'simple' and $num == DAYS_SIMPLE);
			}
			$cms->block('sb_daylog_list'=>$num);
		}
		if ($self->{'count'} > 0) { # hourly report
			for (my $i=0;$i<HOURS_PER_DAY;$i++) {
				my $num = $state{'hour'}{&_pad0($i)};
				$cms->num($i);
				$cms->tag('sb_hourlog_bar'=>int( $num * BAR_MAX_H / $self->{'count'} ));
				$cms->tag('sb_hourlog_num'=>int( $num * 100 / $self->{'count'} )) if ($num);
				$cms->tag('sb_access_bar'=>$barimg);
				$cms->tag('sb_time_class'=>($i % 2) ? 'od' : 'ev');
			}
			$cms->block('sb_hourlog_list'=>HOURS_PER_DAY);
		}
		if ($self->{'count'} > 0) { # report for pages, host, agent, and references
			foreach my $check ('page','host','agnt','refs') {
				my @order  = sort { $state{$check}{$b} <=> $state{$check}{$a} } keys( %{$state{$check}} );
				my $pretag = 'sb_' . $check . 'log_';
				my $num = 0;
				foreach my $elem ( @order ) {
					my $text = sb::Text->entitize($elem);
					$cms->num($num);
					$cms->tag($pretag . $check => $self->_display_elements('mode'=>$check,'text'=>$text));
					$cms->tag($pretag . 'bar' => int( $state{$check}{$elem} * BAR_MAX_W / $self->{'count'} ));
					$cms->tag($pretag . 'num' => $state{$check}{$elem});
					$cms->tag('sb_access_bar'=>$barimg);
					$cms->tag('sb_list_class'=>($num % 2) ? 'odd' : 'even');
					$num++;
					last if ($type eq 'simple' and $num == MAXLOG_SIMPLE);
				}
				$cms->block($pretag . 'list' => $num);
			}
		}
		my $blog = sb::Data->load('Weblog','id'=>0);
		$cms->num(0);
		$cms->tag('sb_blog_name'=>$blog->title);
	} else {
		$cms->num(0);
		$cms->tag('sb_log_days'=>sb::Config->get->value('conf_checklog'));
	}
	$cms->num(0);
	$cms->tag('sb_total_access'=>$self->_load_counter);
	$cms->tag('sb_accesslog_menu_' . $type => 'class="current"');
	$cms->block(($type ne 'setting') ? 'sb_accesslog_log' : 'sb_accesslog_setting' => 1);
	if ($param{'message'} ne '') {
		$cms->num(0);
		$cms->tag('sb_process_message'=>$param{'message'});
		$cms->block('sb_process_message'=>1);
	}
	$self->common_template_parts($cms);
	return sb::Interface->get->head('type'=>'text/html') . $self->set_main($cms->output);
}
# ==================================================
# // private functions - utilities
# ==================================================
sub _load_counter {
	my $self = shift;
	my $file = sb::Config->get->value('dir_data') . sb::Config->get->value('file_access');
	open(TOTALLOG,"<$file");
	my $count = <TOTALLOG>;
	close(TOTALLOG);
	return( int($count) );
}
sub _load_logfile {
	my $self = shift;
	my %param = (
		'expire' => undef,
		@_
	);
	$param{'expire'} ||= DEFAULT_EXPIRES;
	my $conf   = sb::Config->get;
	my $expire = $self->{'time'} - ( $param{'expire'} * HOURS_PER_DAY * SECS_PER_HOUR );
	my $logdir = $conf->value('dir_data') . $conf->value('dir_access');
	my $script = $conf->value('conf_dir_base') . $conf->value('conf_dir_log') . $conf->value('file_logjs');
	my @files  = ();
	my @checks = ();
	opendir(LOGDIR, $logdir);
	@checks = readdir(LOGDIR);
	closedir(LOGDIR);
	foreach my $file (@checks) {
		next if ($file !~ /^\d{8}/);
		my $check = $logdir . $file;
		my $date = (stat($check))[9];
		if ($date < $expire) { # older than expires
			unlink($check);
		} else {
			push(@files,$file);
		}
	}
	if (!-e $script) { # generating script file
		my $js_body = sprintf(&_script_template(),$conf->value('conf_srv_cgi') . $conf->value('basic_cnt'));
		open(COOKOUT,">$script") or die(sb::Language->get->string('error_file_open') . $script);
		binmode(COOKOUT);
		print COOKOUT $js_body;
		close(COOKOUT);
		chmod($conf->value('basic_file_attr'),$script);
	}
	return(@files);
}
sub _display_elements {
	my $self = shift;
	my %param = (
		'mode'   => undef,
		'length' => LOG_MAXLENGTH,
		'text'   => undef,
		@_
	);
	$param{'length'} = LOG_MAXLEN_AGNT if ($param{'mode'} eq 'agnt');
	my $flag = (length($param{'text'}) > $param{'length'});
	my $attr = $flag ? ' title="' . $param{'text'} . '"' : '';
	my $text = $flag ? sb::Text->clip('text'=>$param{'text'},'length'=>$param{'length'}) : $param{'text'};
	if ($param{'mode'} ne 'host' and $param{'mode'} ne 'agnt') {
		$attr .= ' target="_blank"';
		return sprintf('<a href="%s"%s>%s</a>',$param{'text'},$attr,$text);
	} else {
		return sprintf('<span%s>%s</span>',$attr,$text);
	}
}
sub _analyze_log {
	my $self  = shift;
	my $view  = shift;
	my @files = @_;
	my %state = (
		'date' => {},
		'hour' => {},
		'page' => {},
		'host' => {},
		'agnt' => {},
		'refs' => {},
	);
	my $count = 0;
	my $conf  = sb::Config->get;
	my $dir   = $conf->value('dir_data') . $conf->value('dir_access');
	my $zone  = sb::Time->diff_timezone($conf->value('conf_timezone'),0);
	foreach my $file (@files) {
		my $path = $dir . $file;
		open(LOGIN,"<$path") or next;
		while (my $line = <LOGIN>) {
			my @elem = ($line =~ /(.*?)\t/g);
			my @tbuf = gmtime($elem[0] + $zone);
			my $date = ($tbuf[5] + 1900) . '/' .  &_pad0($tbuf[4] + 1) . '/' .  &_pad0($tbuf[3]);
			my $hour = &_pad0($tbuf[2]);
			$state{'date'}{$date}++;
			$state{'hour'}{$hour}++;
			if ($view eq 'simple' and $elem[2] !~ /(.*)\.(\d+)$/) {
				if ($elem[2] =~ /(.*?)\.(.*?)\.(.*?)\.(.*?)$/) {
					$elem[2] = '*.'  . $2 . '.' . $3 . '.' . $4;
				} elsif ($elem[2] =~ /(.*?)\.(.*?)\.(.*?)$/) {
					$elem[2] = '*.'  . $2 . '.' . $3;
				}
			}
			$elem[4] = &_convert_agent($elem[4]) if ($view eq 'simple');
			$state{'host'}{$elem[2]}++ if ($elem[2] ne '');
			$state{'agnt'}{$elem[4]}++ if ($elem[4] ne '');
			my $page = ($elem[5] eq '') ? $elem[3] : $elem[5];
			my $refs = $elem[6] if ($elem[6] ne '');
			$page = substr($page,0,index($page,'#')) if (index($page,'#') > -1);
			if ( index($refs,$conf->value('conf_srv_cgi')) > -1 
			  or index($refs,$conf->value('conf_srv_base')) > -1) {
				$refs = '';
			}
			$state{'page'}{$page}++ if ($page ne '');
			$state{'refs'}{$refs}++ if ($refs ne '');
			$count++;
		}
		close(LOGIN);
	}
	$self->{'count'} = $count;
	return(%state);
}
sub _convert_agent {
	my $agent = shift;
	my ($os,$br) = ();
	$os = 'Win' if ($agent =~ /Win/i);
	if ($os ne '') {
		$os = 'WinXP' if ($agent =~ /NT 5\.1/i or $agent =~ /XP/i);
		$os = 'Win2K' if ($agent =~ /NT 5\.0/i or $agent =~ /2000/i);
		$os = 'WinNT' if ($agent =~ /NT/i and ($os ne 'WinXP' and $os ne 'Win2K'));
		$os = 'Win9x' if ($agent =~ /95/ or $agent =~ /98/ or $agent =~ /9x/i or $agent =~ /Me/i);
	}
	$os = 'Mac'      if ($agent =~ /Mac/i);
	$os = 'Mac OS X' if ($agent =~ /Mac OS X/i);
	$os = 'Mac OS X' if ($os eq 'Mac' and $agent =~ /MSIE 5\.2/);
	$os = 'Linux'    if ($agent =~ /Linux/);
	$br = 'IE5'            if ($agent =~ /MSIE 5/i);
	$br = 'IE5.5'          if ($agent =~ /MSIE 5\.5/i);
	$br = 'IE6'            if ($agent =~ /MSIE 6/i);
	$br = 'OldIE'          if ($agent =~ /MSIE/i and $br eq '');
	$br = 'Safari'         if ($agent =~ /Safari/);
	$br = 'Firefox'        if ($agent =~ /Firefox/ or $agent =~ /Firebird/);
	$br = 'Opera'          if ($agent =~ /Opera/);
	$br = 'Mozilla Series' if ($br eq '' and $agent =~ /Gecko/);
	$agent = $br . ' : ' . $os if ($os and $br);
	return($agent);
}
sub _pad0 { # padding 0
	return( ($_[0] < 10) ? '0' . $_[0] : $_[0] );
}
sub _script_template {
	return <<'__COLLECT_JS__';
document.write('<div class="accesslog"><img src="%s?');
document.write(Array('href=',escape(location.href),'&amp;refe=',escape(document.referrer),'').join(''));
document.write('" width="1" height="1" alt="" /></div>');
__COLLECT_JS__
}
1;
__END__
