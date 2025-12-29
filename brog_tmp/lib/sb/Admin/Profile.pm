# sb::Admin::Profile - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Admin::Profile;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.01';
# 0.01 [2005/06/08] chnaged _update_profile to update correctly
# 0.00 [2005/04/09] generate

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Config ();
use sb::Language ();
use sb::Interface ();
use sb::TemplateManager ();
use sb::Data ();
use sb::Text ();
use sb::Admin::User ();
@ISA = qw( sb::Admin::User );
# ==================================================
# // declaration for constant value
# ==================================================
sub TEMPLATE  (){ 'profile.html' };
sub MAX_LEVEL (){ 2 };
# ==================================================
# // public functions - callback
# ==================================================
sub callback {
	my $self = shift;
	return ($self->{'regi'}) 
		? $self->_update_profile(@_) 
		: $self->_display_profile(@_);
}
# ==================================================
# // private functions - main routine
# ==================================================
sub _update_profile {
	my $self = shift;
	my %param = ( 'message' => '', @_ );
	my $cgi = sb::Interface->get;
	my $lang = sb::Language->get;
	my $msg  = '';
	my $user = sb::Data->load('User','id'=>$cgi->value('pid'));
	return $self->process_message($lang->string('error_unknown')) if (!$user);
	my $name_changed = ($cgi->value('user_name') ne $user->name);
	my $pass_changed = ($cgi->value('user_pass') ne '');
	$msg = $self->check_user(
		'name'       => $cgi->value('user_name'),
		'pass'       => $cgi->value('user_pass'),
		'conf'       => $cgi->value('user_passconf'),
		'check_pass' => $pass_changed,
		'check_name' => $name_changed,
	);
	if (!$msg) {
		$user->name($cgi->value('user_name')) if ( $name_changed );
		$user->pass($cgi->value('user_pass')) if ( $pass_changed );
		$user->real(sb::Text->entitize($cgi->value('user_real')));
		$user->mail(sb::Text->entitize($cgi->value('user_mail')));
		$user->aws(sb::Text->entitize($cgi->value('user_aws')));
		$user->prof($cgi->value('user_prof'));
		$user->disp($cgi->value('user_displist'));
		$user->form($cgi->value('user_prof_breaks'));
		if ($user->id != 0 and $cgi->value('user_stat') ne '') {
			my $level = int($cgi->value('user_stat'));
			$level = 2 if ($level <= 0 or $level > MAX_LEVEL);
			$user->stat($level);
		}
		sb::Data->update($user);
		if ($user->id == $self->{'user'}->id) {
			$self->{'user'} = $user;
			$msg .= $lang->string('parts_userchng') if ( $name_changed );
		}
		$msg .= $lang->string('parts_editcomp');
	}
	$self->build_list('user_list');
	return $self->_display_profile('message'=>$msg);
}
sub _display_profile {
	my $self = shift;
	my %param = ( 'message' => '', @_ );
	my $cgi = sb::Interface->get;
	my $cms = sb::TemplateManager->new($self->load_template('file'=>TEMPLATE));
	my $user = $self->{'user'};
	if ($cgi->value('pid') ne '' and $cgi->value('pid') != $self->{'user'}->id) {
		$user = sb::Data->load('User','id'=>$cgi->value('pid'));
	} else {
		$self->{'mode'} = 'profile';
	}
	return $self->process_message(sb::Langugae->get->string('error_no_user')) if (!$user);
	$self->common_template_parts($cms);
	$cms->num(0);
	$cms->tag('sb_user_name' => $user->name);
	$cms->tag('sb_user_real' => $user->real);
	$cms->tag('sb_user_mail' => $user->mail);
	$cms->tag('sb_user_aws'  => $user->aws); 
	$cms->tag('sb_user_form' => ($user->form ne '') ? 'checked="checked"' : '');
	$cms->tag('sb_user_prof' => sb::Text->entitize($user->prof));
	$cms->tag('sb_user_pid'  => $user->id); 
	$cms->tag('sb_user_displist_' . $user->disp => 'selected="selected"');
	$cms->tag('sb_selected_mode' => $self->{'mode'});
	$self->image_selector( # editor tools - image selector
		'cms'    => $cms,
		'num'    => $self->{'user'}->get_option('imagemax'),
		'option' => $self->{'user'}->get_option('imagelist'),
	);
	$self->display_toolicons( # editor tools - tool icons
		'cms'  => $cms,
		'opt'  => $self->{'user'}->get_option('edit_tool'),
		'set'  => $self->{'user'}->ext,
	);
	if ($user->id == $self->{'user'}->id or $self->{'user'}->stat == 0) {
		$cms->block('sb_profile_changepass'=>1);
	}
	if ($self->{'user'}->stat == 0 and $user->id != 0) {
		$cms->num(0);
		$cms->tag('sb_user_stat_' . $user->stat => 'selected="selected"');
		$cms->block('sb_profile_permission'=>1);
	}
	$cms->block('sb_profile_mode'=>1) if ($self->{'mode'} eq 'profile');
	$cms->block('sb_edituser_mode'=>1) if ($self->{'mode'} eq 'edituser');
	if ($param{'message'} ne '') { # display message
		$cms->num(0);
		$cms->tag('sb_process_message'=>$param{'message'});
		$cms->block('sb_profile_message'=>1);
	}
	return sb::Interface->get->head('type'=>'text/html') . $self->set_main($cms->output);
}
1;
__END__
