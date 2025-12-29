# sb::Receipt - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Receipt;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.28';
# 0.28 [2007/03/17] changed _message/_trackback to handle error message correctly
# 0.27 [2007/03/06] added new member variable for handling error
# 0.26 [2007/02/16] changed _output_trackback to correct encoding
# 0.25 [2007/02/09] changed _sendmail
# 0.24 [2007/02/09] added _handle_receiver
# 0.23 [2007/02/08] changed _message / _trackback to fix a bug
# 0.22 [2007/02/06] changed plugin entry point
# 0.21 [2007/01/05] changed _message to fix a bug
# 0.20 [2006/11/27] changed _output_message
# 0.19 [2006/11/09] changed bracket rule / ignored _check_charset temporarily
# 0.18 [2006/10/14] changed _check_charset
# 0.17 [2006/10/07] changed _trackback to check charset
# 0.16 [2006/09/30] changed _message and _trackback to check status correctly
# 0.15 [2006/09/10] changed _message and _trackback to check spam before sb::Data->add and handle status
# 0.14 [2005/10/19] changed _convert_message_text to conver linefeed as well, added _load_objs
# 0.13 [2005/10/18] changed _output_trackback to pass TemplateManager object to sb::Content
# 0.12 [2005/10/13] changed _trackback to ignore trachbacks which have no body
# 0.11 [2005/08/23] chnaged _message and _trackback to ban those when entry is closed
# 0.10 [2005/08/12] changed _check_ip to check ip more precisely
# 0.09 [2005/07/25] changed issue to call plugins
# 0.08 [2005/07/20] chnaged _sendmail to detitize text in mail body
# 0.07 [2005/07/16] changed _buikd_files to change the order of building files
# 0.06 [2005/07/08] changed _message to store cookie
# 0.05 [2005/07/08] fixed a bug in _check_departure to check caller correctly
# 0.04 [2005/06/29] fixed a bug in _sendmail, changed _trackback & _message to set tz
# 0.03 [2005/06/09] changed new to add 'caller' to instance value
# 0.02 [2005/06/07] changed _sendmail
# 0.01 [2005/06/01] build files after receiving
# 0.00 [2005/02/28] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Language ();
use sb::Config ();
use sb::Data ();
use sb::Lock ();
use sb::Time ();
use sb::Mailer ();
use sb::TemplateManager ();
use sb::Content ();
use sb::Text ();
use sb::Build ();
use sb::App ();
@ISA = qw( sb::App );
# ==================================================
# // declaration for constant value
# ==================================================
sub PING_ERROR_DENIED  (){ "The ping is denied.\n" };
sub PING_ERROR_NO_URL  (){ "URL field is necessary.\n" };
sub PING_ERROR_NOENTRY (){ "There is no entry.\n" };
sub PING_ERROR_UNKNOWN (){ "Uknown error\n" };
sub PING_RESPONSE_RSS  (){ 'request to output as rss' };
sub PING_RESPONSE_VIEW (){ 'request to output as view' };
sub TEMPLATE_MAIL_COM  (){ 'notification_comment.txt' };
sub TEMPLATE_MAIL_TB   (){ 'notification_trackback.txt' };
sub TEMPLATE_RSS_TB    (){ 'rss_for_trackback.rdf' };
sub CONTENT_TYPE       (){ 'text/xml' };
sub OUTPUT_CHARSET     (){ 'utf-8' };
sub COOKIE_CHARCODE    (){ 'utf8' };
sub COOKIE_EXPIRES     (){ 8544 }; # 8544 = 365 days
sub ERROR_TITLE        (){ ' | Notification' };
# ==================================================
# // constructor
# ==================================================
sub new
{
	my $class = shift;
	my $self = {
		'mode'  => undef, # mode => com or tb
		'cgi'   => undef, # cgi interface
		'id'    => undef, # id for entry
		'time'  => undef, # current time
		'error' => undef, # error message
		@_
	};
	$self->{'caller'} = (caller)[1]; # store caller
	return bless($self,$class);
}
# ==================================================
# // public functions
# ==================================================
sub issue
{
	my $self = shift;
	my $lang = sb::Language->get;
	if ( !defined($self->{'mode'}) 
	  or !defined($self->{'id'}) 
	  or !defined($self->{'cgi'}) 
	  or !defined($self->{'time'}) )
	{
		die($lang->string('error_unknown'));
	}
	my $lock = sb::Lock->lock or die($lang->string('error_file_lock'));
	my ($entry,$error) = ($self->{'mode'} eq 'tb') ? $self->_trackback : $self->_message;
	if ($entry and !$error)
	{
		sb::Data->update($entry);
		$self->_build_files($entry);
	}
	$lock->unlock;
	return ($self->{'mode'} eq 'tb') 
		? $self->_output_trackback($error) 
		: $self->_output_message($error);
}
# ==================================================
# // private functions - main
# ==================================================
sub _trackback
{ # receiving trackback, this function should return an entry object and error message
	my $self  = shift;
	my $entry = sb::Data->load('Entry','id'=>$self->{'id'});
	my $now   = $self->{'time'};
	my $cgi   = $self->{'cgi'};
	my $conf  = sb::Config->get;
	my $lang  = sb::Language->get;
	return($entry,PING_ERROR_NOENTRY) if (!$entry);
	$lang->checkcode( # set charset for sb::Language
		$cgi->value('excerpt'),
		$lang->code_for_charset($cgi->value('charset'))
	);
	return($entry,PING_RESPONSE_RSS) if ($cgi->value('__mode') eq 'rss');
	my %tb = ( # buffering data for received trackback
		'eid'  => $entry->id,
		'stat' => 1,
		'date' => $now,
		'body' => $lang->convert($cgi->value('excerpt')),
		'subj' => $lang->convert($cgi->value('title')),
		'name' => $lang->convert($cgi->value('blog_name')),
		'url'  => $lang->convert($cgi->value('url')),
		'tz'   => sb::Config->get->value('conf_timezone'),
		'host' => $cgi->value('_addr'),
	);
	my $num  = $entry->tb;
	eval { # error check
		die(PING_ERROR_NO_URL) if ( $tb{'url'} eq '' or !&_check_url($tb{'url'}) );
		die(PING_ERROR_DENIED) if ( $tb{'body'} eq '' or $tb{'body'} =~ /^\s*$/ );
		die(PING_ERROR_DENIED) if ( $entry->atb == 0 );
		die(PING_ERROR_DENIED) if ( $entry->stat == 0 );
		die(PING_ERROR_DENIED) if ( $cgi->value('_refe') ne '' );
		die(PING_ERROR_DENIED) if ( !&_check_ip($cgi->value('_addr')) );
		die(PING_ERROR_DENIED) if ( !&_check_agent($cgi->value('_agnt')) );
	};
	return($entry,$@) if ($@);
	return($entry,PING_ERROR_DENIED) if ($self->_handle_receiver($entry,'tb',\%tb));
	return($entry, $self->{'error'}) if ($self->{'error'} ne '');
	my @objs = &_load_objs('Trackback',$entry->id);
	my $new = &_check_redundancy_for_tb(\%tb,@objs);
	if (!$new)
	{
		$new = sb::Data->add('Trackback',%tb);
		$entry->tb( ++$num ) if ($new->stat == 1);
		$self->_sendmail('tb',$new,$entry);
	}
	sb::Data->update($new) if ($new);
	return($entry,'');
}
sub _output_trackback
{
	my $self  = shift;
	my $error = shift;
	my $out = '';
	if ( $error eq PING_RESPONSE_RSS )
	{
		my $cms = sb::TemplateManager->new($self->load_template('file' => TEMPLATE_RSS_TB));
		$out .= $self->{'cgi'}->head('type'=>CONTENT_TYPE);
		$out .= sb::Content->output($cms,
			'mode'   => 'ent',
			'id'     => $self->{'id'},
			'time'   => $self->{'time'},
			'extend' => {'trackback' => {'rss' => \&_trackback_rss_callback}},
		);
	}
	else
	{
		chomp($error) if ($error);
		$out .= $self->{'cgi'}->head('type'=>CONTENT_TYPE,'charset'=>OUTPUT_CHARSET);
		$out .= '<?xml version="1.0" encoding="utf-8"?>' . "\n";
		$out .= '<response>' . "\n";
		$out .= ($error) ? '<error>1</error>' . "\n" : '<error>0</error>' . "\n";
		$out .= '<message>' . $error . '</message>' . "\n" if ($error);
		$out .= '</response>' . "\n";
	}
	return( $out );
}
sub _message
{ # receiving comment, this function should return an entry object and error message
	my $self  = shift;
	my $entry = sb::Data->load('Entry','id'=>$self->{'id'});
	my $now   = $self->{'time'};
	my $cgi   = $self->{'cgi'};
	my $lang  = sb::Language->get;
	return($entry,"error_no_entry\n") if (!$entry);
	my $code = ($cgi->value('charset') eq '') # charcode not charset to use sb::Language
	         ? $lang->charcode 
	         : $lang->code_for_charset($cgi->value('charset'));
	$lang->checkcode($cgi->value('description'),$code);
	my %com = ( # buffering data for received comment
		'eid'  => $entry->id,
		'stat' => 1,
		'date' => $now,
		'tz'   => sb::Config->get->value('conf_timezone'),
		'body' => &_convert_message_text('description',$cgi,$lang),
		'auth' => &_convert_message_text('name',$cgi,$lang),
		'mail' => $cgi->value('email'),
		'url'  => $cgi->value('url'),
		'host' => $cgi->value('_addr'),
		'agnt' => $cgi->value('_agnt'),
		'icon' => $cgi->value('icon'),
	);
	$com{'icon'} = int($com{'icon'}) if ($com{'icon'} ne '');
	my $num  = $entry->com;
	my @objs = &_load_objs('Message',$entry->id);
	eval { # error check
		die("error_no_comment\n") if ( $com{'body'} eq '' );
		die("error_banned\n")     if ( $entry->acm == 0 );
		die("error_banned\n")     if ( !&_check_charset($cgi->value('charset')) );
		die("error_no_entry\n")   if ( $entry->stat == 0 );
		die("error_banned\n")     if ( !&_check_ip($cgi->value('_addr')) );
		die("error_doubled\n")    if ( &_check_redundancy_for_com(\%com,@objs) );
	};
	return($entry,$@) if ($@);
	return($entry,"error_banned\n") if ($self->_handle_receiver($entry,'com',\%com));
	return($entry, $self->{'error'}) if ($self->{'error'} ne '');
	my $new = sb::Data->add('Message',%com);
	if ($new)
	{
		$entry->com( ++$num ) if ($new->stat == 1);
		$self->_sendmail('com',$new,$entry);
		sb::Data->update($new);
	}
	if ($cgi->value('set_cookie'))
	{ # set cookies
		my $conf = sb::Config->get;
		my %data = ();
		$lang->checkcode('',$code) if ($code ne COOKIE_CHARCODE);
		foreach my $key ( @{$conf->value('basic_cookie')} )
		{
			my $value = ($key ne 'checkid') ? $cgi->value($key) : $conf->value('conf_spamid');
			$value = $lang->convert($value,COOKIE_CHARCODE) if ($code ne COOKIE_CHARCODE);
			$data{$key} = $value;
		}
		$cgi->set_cookie(
			'time'   => $now,
			'name'   => $conf->value('basic_cooktag'),
			'expire' => COOKIE_EXPIRES,
			'data'   => \%data,
		);
	}
	my $msg = '';
	$msg = ($new->stat == 0) ? "error_wait_msg\n" : "error_saved_as_closed\n" if ($new->stat != 1);
	return($entry,$msg);
}
sub _output_message
{
	my $self = shift;
	my $error = shift;
	my $out = '';
	if ($error)
	{
		chomp($error) if ($error =~ /\n$/);
		$out = ($error eq 'error_banned')
			? $self->{'cgi'}->head('status'=>'403 Forbidden')
			: $self->{'cgi'}->head('type'=>'text/html');
		$out .= $self->_error_message( sb::Language->get->string($error) );
	}
	else
	{
		my $redirect = $self->_check_departure( sb::Data->load('Entry','id'=>$self->{'id'}) );
		$redirect .= '&com=0' if (index($self->{'caller'},'Mobile.pm') > -1);
		$out = $self->{'cgi'}->head('location'=>$redirect);
	}
	return($out);
}
sub _error_message
{
	my $self = shift;
	my $message = shift;
	my $cms = sb::TemplateManager->new( &sb::App::_error_template() );
	$cms->num(0);
	$cms->tag('sb_site_title'=>$sb::PRODUCT . ERROR_TITLE);
	$cms->tag('sb_error_title'=>sb::Language->get->string('parts_error'));
	$cms->tag('sb_error'=>$message);
	$cms->tag('sb_site_top'=>sb::Config->get->value('conf_srv_base'));
	$self->common_template_parts($cms);
	return $cms->output;
}
sub _handle_receiver
{
	my $self  = shift;
	my $entry = shift;
	my $type  = shift;
	my $obj   = shift;
	my $conf = sb::Config->get;
	my @funcs = sb::Plugin->load_extra_module('receipt');
	if ( $type eq 'com'
	  or ($type eq 'tb' and $conf->value('conf_spamtb')) )
	{ # add default handler
		push(@funcs,\&_check_spam);
	}
	my $acceptance = ($type eq 'tb') ? $entry->atb : $entry->acm;
	my %flag = (
		'black'=>undef,
		'white'=>undef,
		'close'=>undef
	);
	foreach my $func (@funcs)
	{
		eval {
			my $spam = &$func($self,$entry,$type,$obj);
			if ($spam > 0)
			{ # black
				$flag{'black'} = 1;
			}
			elsif ($spam < 0)
			{ # white
				$flag{'white'} = 1;
			}
			elsif ($obj->{'stat'} == -1)
			{ # gray and stat is set as 'closed'
				$flag{'close'} = 1;
			}
			$obj->{'stat'} = 1; # put stat back to 1
		};
	}
	if ($flag{'black'})
	{ # black - probably spam
		return( 1 ) if (!$flag{'white'} and $conf->value('conf_spamstat'));
		$obj->{'stat'} = 0;
	}
	else
	{ # not black
		if ($acceptance == 2)
		{
			$obj->{'stat'} = 0;
		}
		elsif ($flag{'close'})
		{
			$obj->{'stat'} = -1;
		}
		else
		{
			$obj->{'stat'} = 1;
		}
	}
	return;
}
sub _sendmail
{
	my $self = shift;
	my ($mode,$obj,$entry) = @_;
	my $blog = sb::Data->load('Weblog','id'=>0);
	return if ($blog->smtp eq '' or $blog->stype eq '');
	my ($to,$from,$body) = ();
	my @to = ();
	my @users = sb::Data->load('User','cond'=>{'notice'=>1});
	my $admin = sb::Config->get->value('conf_srv_cgi') . sb::Config->get->value('basic_admn');
	foreach my $user (@users)
	{
		next if (!$user->mail);
		$from = $user->mail if ($from eq '');
		push(@to,$user->mail);
	}
	$to = join(', ',@to);
	return if ($to eq '' or $from eq '');
	my $cms = sb::TemplateManager->new(
		$self->load_template(
			'file' => ($mode eq 'tb') ? TEMPLATE_MAIL_TB : TEMPLATE_MAIL_COM
		)
	);
	my $date = sb::Time->format(
		'time'=>$obj->date,
		'form'=>sb::Config->get->value('conf_msg_time'),
		'zone'=>$obj->tz,
		'lang'=>sb::Config->get->value('conf_time_lang'),
	);
	$cms->num(0);
	$cms->tag('notification_title'=>sb::Language->get->string('parts_body_' . $mode));
	$cms->tag('entry_title'=>$entry->subj);
	$cms->tag('entry_parmalink'=>$entry->permalink);
	$cms->tag('receive_date'=>$date);
	$cms->tag('product_name'=>$sb::PRODUCT . ' ' . $sb::VERSION . ' ' . $sb::WEBPAGE);
	if ($mode eq 'tb')
	{
		$cms->tag('tb_blogname'=>$obj->name);
		$cms->block('tb_blogname'=>1) if ($obj->name ne '');
		$cms->tag('tb_title'=>$obj->subj);
		$cms->block('tb_title'=>1) if ($obj->subj ne '');
		$cms->tag('tb_url'=>$obj->url);
		$cms->tag('tb_host'=>$obj->host);
		$cms->tag('tb_admin_link'=>$admin . '?__mode=trackback&bid=' . $obj->id);
		$cms->tag('tb_excerpt'=>sb::Text->detitize($obj->formated_body));
	}
	else
	{
		$cms->tag('com_name'=>$obj->auth);
		$cms->block('com_name'=>1) if ($obj->auth ne '');
		$cms->tag('com_mail'=>$obj->mail);
		$cms->block('com_mail'=>1) if ($obj->mail ne '');
		$cms->tag('com_url'=>$obj->url);
		$cms->block('com_url'=>1) if ($obj->url ne '');
		$cms->tag('com_host'=>$obj->host);
		$cms->tag('com_admin_link'=>$admin . '?__mode=comment&mid=' . $obj->id);
		$cms->tag('com_body'=>sb::Text->detitize($obj->body));
	}
	my $mailer = sb::Mailer->new(
		'sender'       => $blog->stype,
		'send_server'  => $blog->smtp,
		'charcode'     => sb::Language->get->charcode,
	);
	$mailer->sendmail(
		'To'      => $to,
		'From'    => $from,
		'Subject' => sb::Language->get->string('parts_subj_' . $mode),
		'Body'    => $cms->output,
	);
}
# ==================================================
# // private functions - utilities
# ==================================================
sub _check_spam
{
	my $self = shift;
	my ($entry,$type,$obj) = @_;
	my $conf = sb::Config->get;
	my $lang = sb::Language->get;
	my $level = $conf->value('conf_spamlevel');
	if ($level > 0)
	{
		if ($level < 3 and $type ne 'tb')
		{ # level 1 and 2
			my $refe = $self->{'cgi'}->value('_refe');
			my ($check_ref,$check_id);
			my $cookie = sb::Interface->get->cookie('name'=>$conf->value('basic_cooktag'));
			$check_ref = $self->_check_departure($entry);
			return( 1 ) if (index($refe,$check_ref) == -1); # level 1
			$check_ref = $entry->permalink('type'=>'None');
			$check_id = $cookie->{'checkid'};
			return( 1 ) if (  $level > 1 and $check_id ne $conf->value('conf_spamid')); # level 2
		}
		elsif ($level == 3 and $lang->code eq 'ja' and $obj->{'body'} !~ m/[\x80-\xff]/)
		{ # level 3 [Japanese only]
			return( 1 );
		}
		elsif ($level >= 4)
		{ # level 4
			my @conds = split("\n",$conf->value('conf_spamword'));
			foreach my $cond (@conds)
			{
				my ($field,$val) = split('=',$cond,2);
				my $check = $obj->{'body'};
				next if ($type eq 'tb' and $field eq 'mail');
				$check = $obj->{'mail'} if ($field eq 'mail');
				$check = $obj->{($type eq 'tb') ? 'name' : 'auth'} if ($field eq 'name');
				$check = $obj->{'url'}  if ($field eq 'url');
				return( 1 ) if (index($check,$val) > -1 or index(lc($check),lc($val)) > -1);
			}
			if ($level == 5 and $lang->code eq 'ja' and $obj->{'body'} !~ m/[\x80-\xff]/)
			{ # level 5 [Japanese only]
				return( 1 );
			}
		}
	}
	return( 0 ); # passed default spam check
}
sub _check_departure
{
	my $self  = shift;
	my $entry = shift;
	my $type = (index($self->{'caller'},'Mobile.pm') > -1) 
	         ? 'Mobile' 
	         : sb::Config->get->value('conf_entry_archive');
	$type = 'None' if ($type eq 'Monthly');
	return $entry->permalink('type'=>$type);
}
sub _check_charset
{
	my $charset = shift;
	my $lang = sb::Language->get;
	my $level = sb::Config->get->value('conf_spamword');
	$charset = $lang->code_for_charset($charset);
	return(0) if ($charset eq '');
	return(1) if ($charset eq 'utf8');
	if ($lang->code eq 'ja' and ($level == 3 or $level == 5))
	{
		return(1) if ($charset eq 'euc' or $charset eq 'jis' or $charset eq 'sjis');
		return(0);
	}
	return(1);
}
sub _check_redundancy_for_com
{
	my ($hash_ref,@array) = @_;
	my %com = %{$hash_ref};
	foreach my $obj ( @array )
	{
		return(1) if ( $com{'auth'} eq $obj->auth and $com{'body'} eq $obj->body );
	}
	return( undef );
}
sub _check_redundancy_for_tb
{
	my ($hash_ref,@array) = @_;
	my %tb = %{$hash_ref};
	foreach my $obj ( @array )
	{
		if ( $tb{'url'} eq $obj->url )
		{
			$obj->date($tb{'date'});
			$obj->body($tb{'body'});
			$obj->subj($tb{'subj'});
			$obj->name($tb{'name'});
			$obj->host($tb{'host'});
			return($obj);
		}
	}
	return( undef );
}
sub _check_agent
{
	my $agnt = shift;
	my $check = 1;
	my @aDenied = ('Mozilla/');
	foreach my $list ( @aDenied )
	{
		$check = 0 if (index($agnt,$list) == 0);
		last if (!$check);
	}
	return($check);
}
sub _check_url
{
	return( $_[0] =~ /s?https?:\/\/[-_.!~*\'()a-zA-Z0-9;\/?:\@&=+\$,%#]+/ );
}
sub _check_ip
{
	my $addr = shift;
	my $check = 1;
	my @ban_list = split("\n",sb::Config->get->value('conf_ip_ban'));
	foreach my $ban_ip ( @ban_list )
	{
		$check = 0 if ($addr =~ /^$ban_ip/);
		last if (!$check);
	}
	return($check);
}
sub _load_objs
{
	my ($class,$eid) = @_;
	my @buffer = sb::Data->load($class,'cond'=>{'eid'=>$eid});
	my @objs =();
	for (my $i=0;$i<@buffer;$i++)
	{
		my $obj = sb::Data->load($class,'id'=>$buffer[$i]->id);
		push(@objs,$obj) if ($obj);
	}
	return @objs;
}
sub _convert_message_text
{
	my ($elem,$cgi,$lang) = @_;
	my $output = '';
	my $text = $cgi->value($elem);
	my $ua   = $cgi->value('_agnt');
	# sanitizing text from mobile terminal
	#  => reference from http://specters.net/cgipon/labo/it_emoji.html
	if ($ua =~ /DoCoMo/ && $text =~ /[\xF8\xF9]/)
	{
		while (1)
		{
			if ($text =~ s/^[\xF8\xF9][\x40-\x7E\x80-\xFC]//)
			{
				$output .= '&#' . unpack('n', $&) . ';';
			}
			elsif ($text =~ s/^([\x81-\x9F\xE0-\xF7\xFA-\xFC][\x40-\x7E\x80-\xFC])+//)
			{
				$output .= $&;
			}
			elsif ($text =~ s/^.//)
			{
				$output .= $&;
			}
			else
			{
				last;
			}
		} # end of while(1)
	} # end of if ($ua =~ /DoCoMo/ && $text =~ /[\xF8\xF9]/)
	else
	{
		$output = $text;
	}
	$output =~ s/\x0D\x0A/\n/g;
	$output =~ tr/\x0D\x0A/\n\n/;
	while ($output =~ /\n$/)
	{
		$output =~ s/\n$//g;
	}
	$output = $lang->convert($output);
	return sb::Text->entitize($output);
}
sub _trackback_rss_callback
{
	my $cms  = shift;
	my $tb   = shift;
	my %var  = @_;
	$cms->tag('trackback_title_only'=>$tb->subj);
	$cms->tag('trackback_url_only'=>$tb->url);
}
sub _build_files
{ # building files
	my $self = shift;
	my $entry = shift;
	return( undef ) if (!$entry);
	my %cat  = sb::Data->load_as_hash('Category');
	my %user = sb::Data->load_as_hash('User');
	my $builder = sb::Build->new(
		'time'      => $self->{'time'},
		'user'      => \%user,
		'cat'       => \%cat,
		'sortedcat' => [ sort { $b->order <=> $a->order } values(%cat) ],
		'blog'      => sb::Data->load('Weblog','id'=>0),
	);
	if (sb::Config->get->value('conf_entry_archive') eq 'Individual')
	{
		$builder->build_javascript('recent_comment_list') if ($self->{'mode'} eq 'com');
		$builder->build_javascript('recent_trackback_list') if ($self->{'mode'} eq 'tb');
		$builder->build_entry( $entry ) if ($entry->stat != 0);
	}
	elsif (sb::Config->get->value('conf_entry_archive') eq 'Monthly')
	{
		my $month = sb::Time->format(
			'time'=>$entry->date,
			'form'=>'%Year%%Mon%',
			'zone'=>$entry->tz
		);
		$builder->build_monthly_archive( $month );
	}
	$builder->build_category_index( $entry->cat ) if ($entry->cat ne '');
	$builder->build_top_page;
	return(1);
}
1; # end of package
__END__
