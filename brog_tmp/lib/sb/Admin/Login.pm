# sb::Admin::Login - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Admin::Login;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.01';
# 0.02 [2005/08/11] changed _open_login_panel to put hidden parameters correctly
# 0.01 [2005/06/07] changed _open_login_panel to implement bookmarklet
# 0.00 [2005/02/02] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Config ();
use sb::Language ();
use sb::Interface ();
use sb::TemplateManager ();
use sb::Text ();
use sb::Data ();
use sb::App::Admin ();
@ISA = qw( sb::App::Admin );
# ==================================================
# // declaration for constant value
# ==================================================
sub COOKIE_USER (){ 'user' };
# ==================================================
# // declaration for class member
# ==================================================
my @mIgnoreParam = (
	'_path',
	'_refe',
	'_host',
	'_addr',
	'_agnt',
	'__user',
	'__pass',
	'upload_file',
	'temp_package',
	'import_data',
);
# ==================================================
# // public functions - callback
# ==================================================
sub callback {
	my $self = shift;
	return $self->_open_login_panel(@_);
}
# ==================================================
# // private functions - main routine
# ==================================================
sub _open_login_panel {
	my $self = shift;
	my %param = ( 'message' => '', @_ );
	my $cgi = sb::Interface->get;
	my $cookie = $cgi->cookie('name'=>sb::Config->get->value('basic_admntag') . COOKIE_USER);
	my $cms = sb::TemplateManager->new($self->load_template);
	$self->common_template_parts($cms);
	$self->_set_title($cms);
	$cms->num(0);
	$cms->tag('sb_body_class'=>($cgi->value('__mode') ne 'bm') ? 'main' : 'bm');
	$cms->block('sb_mainbody'=>0);
	$cms->block('sb_login'=>1);
	$cms->block('sb_mainhead'=>1) if ($cgi->value('__mode') ne 'bm');
	if ( $param{'message'} ne '' ) {
		$cms->block('sb_login_msg'=>1);
		$cms->tag('sb_login_message'=>$param{'message'});
	}
	$cms->tag('cookie_user'=>( $self->{'user'} ) ? $self->{'user'}->name : $cookie->{'user'} );
	$cms->tag('sb_menu_help'=>sb::Config->get->value('srv_doc') . sb::Language->get->code . '.html');
	if ( $param{'message'} ne sb::Language->get->string('error_not_allow') ) {
		my $hidden = '';
		foreach my $key ( $cgi->names ) {
			next if (grep(/^$key/,@mIgnoreParam));
			$hidden .= $self->_hidden_parameter($key,$cgi->value($key));
		}
		$cms->tag('sb_bm_para'=>$hidden);
	}
	return sb::Interface->get->head('type'=>'text/html') . $cms->output;
}
# ==================================================
# // private functions - for login panel
# ==================================================
sub _hidden_parameter {
	my $self = shift;
	my ($key,$value) = @_;
	$value = sb::Text->entitize($value);
	return '<input type="hidden" name="' . $key . '" value="' . $value . '" />';
}
1;
__END__
