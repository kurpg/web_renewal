# sb::App - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::App;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.02';
# 0.02 [2006/02/16] changed common_template_parts
# 0.01 [2005/07/11] changed config variable "srv_cgi" to "conf_srv_cgi"
# 0.00 [2005/02/02] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use LWP::UserAgent ();
use sb::Interface ();
use sb::Language ();
use sb::Config ();
use sb::TemplateManager ();
use sb::Time ();
use sb::Content ();
# ==================================================
# // declaration for constant value
# ==================================================
sub CSS_NAME      (){ 'style.css' };
sub DEFAULT_CODE  (){ 'euc' };
sub PARTS_DIR     (){ '_parts/' };
sub ERROR_TITLE   (){ ' | Notification' };
sub HOURS_PER_DAY (){ 24 };
sub SECS_PER_HOUR (){ 3600 };
sub MAX_LEVEL     (){ 2 };
# ==================================================
# // constructor
# ==================================================
sub new
{
	my $class = shift;
	return bless({ @_ },$class);
}
# ==================================================
# // public functions - class method
# ==================================================
sub error
{
	my $self = shift;
	my $message = shift;
	my $cms = sb::TemplateManager->new( &_error_template() );
	my $top = (index((caller)[1],'Admin') == -1)
	        ? sb::Config->get->value('conf_srv_base')
	        : sb::Config->get->value('conf_srv_cgi') . sb::Config->get->value('basic_admn');
	$cms->num(0);
	$cms->tag('sb_site_title'=>$sb::PRODUCT . ERROR_TITLE);
	$cms->tag('sb_error_title'=>sb::Language->get->string('parts_error'));
	$cms->tag('sb_error'=>$message);
	$cms->tag('sb_site_top'=>$top);
	$self->common_template_parts($cms);
	return sb::Interface->get->head('type'=>'text/html') . $cms->output;
}
# ==================================================
# // public functions - template parts
# ==================================================
sub get_parts_dir
{
	my $self = shift;
	return( sb::Config->get->value('dir_temp') );
}
sub load_template
{
	my $self = shift;
	my %param = (
		'file' => undef,
		'dir'  => $self->get_parts_dir,
		@_
	);
	return( undef ) if ($param{'file'} eq '');
	my $file = $param{'dir'} . $param{'file'};
	my $lang = sb::Language->get;
	my $text = undef;
	my @template = ();
	if ( -r $file ) {
		open(TEMPIN,"<$file") or die(sb::Language->get->string('error_file_open') . $file);
		binmode(TEMPIN);
		while (my $line = <TEMPIN>) {
			$line =~ tr/\x0D\x0A//d;
			push(@template,$line);
		}
		close(TEMPIN);
	}
	$text = join("\n",@template);
	if (sb::Config->get->value('basic_temp_conv') and $lang->charcode ne DEFAULT_CODE) {
		$lang->checkcode('',DEFAULT_CODE);
		$text = $lang->convert($text,$lang->charcode);
	}
	return($text);
}
sub common_template_parts
{
	my $self = shift;
	my $cms  = shift;
	return if (!$cms or !$self);
	$cms->num(0);
	$cms->tag('sb_site_css'=>sb::Config->get->value('srv_temp') . sb::Language->get->code . '/' . CSS_NAME);
	$cms->tag('sb_site_template'=>sb::Config->get->value('srv_temp') . PARTS_DIR);
	$cms->tag('sb_site_encoding'=>sb::Language->get->charset);
	$cms->tag('sb_site_lang'=>sb::Language->get->code);
	$cms->tag('sb_buildno'=>$sb::BUILDNO);
	$cms->tag('sb_version'=>$sb::VERSION);
	$cms->tag('sb_product_name'=>$sb::PRODUCT);
	$cms->tag('sb_webpage'=>$sb::WEBPAGE);
	return;
}
# ==================================================
# // public functions - utilities
# ==================================================
sub create_date_condition
{
	my $self = shift;
	my $date = shift;
	my ($year,$mon,$day) = ( $date =~ /(\d\d\d\d)(\d\d)(\d\d)?/ );
	my $start_date = ($day == 0)
		? sb::Time->convert('year' => $year,'mon' => $mon,)
		: sb::Time->convert('year' => $year,'mon' => $mon,'day' => $day,);
	my $end_date = $start_date;
	if ($day == 0) {
		$year++ if ($mon == 12);
		$mon = ($mon == 12) ? 1 : $mon + 1;
		$end_date = sb::Time->convert('year' => $year,'mon' => $mon,);
	} else {
		$end_date = $start_date + HOURS_PER_DAY * SECS_PER_HOUR;
	}
	return [$start_date,$end_date];
}
sub check_entry_body
{
	my $self = shift;
	my $body = shift;
	return ($body eq '') ? 'no_body' : undef;
}
sub init_agent
{ # initialization of LWP::UserAgent
	my $self = shift;
	my $ua;
	$ua = LWP::UserAgent->new;
	$ua->parse_head(0); # ignore to load HTML::Parser
	$ua->agent($sb::PRODUCT . '/' . $sb::VERSION);
	$ua->timeout(300);
	if (sb::Config->get->value('basic_http_proxy')) { # set proxy
		$ua->proxy('http' => sb::Config->get->value('basic_http_proxy'));
	}
	return($ua);
}
# ==================================================
# // public functions - administration
# ==================================================
sub check_permission
{
	my $self = shift;
	my %param = (
		'level' => undef,
		'user'  => undef,
		@_
	);
	return( undef ) if ( !$self->{'users'} );
	return( undef ) if ( !$self->{'user'} );
	if ( defined($param{'user'}) ) {
		return(1) if ( $self->{'user'}->id == $param{'user'} );
		return(1) if ( !$self->{'users'}->{$param{'user'}} );
		return(1) if ( $self->{'user'}->stat < $self->{'users'}->{$param{'user'}}->stat );
	} elsif ( defined($param{'level'}) ) {
		return(1) if ( $self->{'user'}->stat <= MAX_LEVEL - $param{'level'} );
	}
	return( undef );
}
sub check_password
{
	my $self = shift;
	my %param = (
		'user' => undef,
		'pass' => undef,
		@_
	);
	return( 1 ) if ( !$self->{'users'} );
	return( 1 ) if ($param{'user'} eq '' or $param{'pass'} eq '');
	foreach my $id ( keys( %{$self->{'users'}} ) ) {
		my $user = $self->{'users'}->{$id};
		next if ( $user->name ne $param{'user'} );
		$self->{'user'} = sb::Data->load('User','id'=>$user->id);
		return( undef ) if ( $user->check_pass($param{'pass'}) );
	}
	return( 1 );
}
# ==================================================
# // private functions
# ==================================================
sub _error_template
{ # default error template
	return <<'__ERROR_TEMPLATE__';
<?xml version="1.0" encoding="{sb_site_encoding}"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="{sb_site_lang}">
<head>
<meta http-equiv="Content-Type" content="text/html; charset={sb_site_encoding}" />
<meta name="generator" content="{sb_product_name}" />
<link rel="stylesheet" type="text/css" href="{sb_site_css}" title="default" media="screen,tv" />
<title>{sb_site_title}</title>
</head>
<body>
<h1><img src="{sb_site_template}title_gray.jpg" width="700" height="50" alt="{sb_product_name}" /></h1>
<h2 class="error">{sb_error_title}</h2>
<p class="msg">{sb_error}</p>
<p class="msg"><a href="{sb_site_top}">return to top</a></p>
<address>Powered by <a href="{sb_webpage}">{sb_product_name}</a> {sb_version}</address>
<address>Copyright &copy; SimpleBoxes 2004-, All rights reserved.</address>
</body>
</html>
__ERROR_TEMPLATE__
}
1;
__END__
