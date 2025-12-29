# sb::Admin::Editor - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Admin::Editor;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.00';
# 0.00 [2005/04/09] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Config ();
use sb::Plugin ();
use sb::Interface ();
use sb::Admin::Entry ();
@ISA = qw( sb::Admin::Entry );
# ==================================================
# // declaration for constant value
# ==================================================
sub TEMPLATE      (){ 'editor.html' };
sub DEFAULT_TYPE  (){ 'basic' };
sub STYLESET_FILE (){ 'default_styleset.cgi' };
# ==================================================
# // declaration for class member
# ==================================================
my %mEditorType = (
	'basic' => {'form' => 'subform',  'submit'=>1, },
	'tags'  => {'form' => 'mainform', 'submit'=>1, },
	'mail'  => {'form' => 'subform',  'submit'=>1, },
	'sbit'  => {'form' => 'mainform', 'submit'=>0, },
);
# ==================================================
# // public functions - callback
# ==================================================
sub callback { # コールバック
	my $self = shift;
	return ( $self->{'regi'} ) 
		? $self->_save_setting(@_)
		: $self->_open_setting(@_);
}
# ==================================================
# // private functions - main routine
# ==================================================
sub _save_setting {
	my $self = shift;
	my %param = ( 'message' => '', @_ );
	my $cgi = sb::Interface->get;
	my $lang = sb::Language->get;
	my $user = $self->{'user'};
	SWITCH_TYPE: {
		$_ = $cgi->value('__type');
		/^basic$/ && do {
			foreach my $key ($user->get_option_keys) {
				next if ($key eq 'format' or $key eq 'status' or $key eq 'edit_tool');
				$user->set_option($key => int($cgi->value('editor_' . $key)));
			}
			$user->set_option('format'=>$self->_sanitize_text($cgi->value('editor_format')));
			$user->cat($cgi->value('editor_category'));
			$user->ad_css($cgi->value('editor_admin_style'));
			if ($cgi->value('update_ping_check')) {
				sb::Config->get->value('conf_edit_ping' => $cgi->value('editor_pinglist'));
				sb::Config->store();
			}
			last SWITCH_TYPE;
		};
		/^tags$/ && do {
			my @sets = ();
			my $ext = '';
			push(@sets,( $cgi->value('editor_toolurl') ne '' ) ? 0 : 1);
			push(@sets,( $cgi->value('editor_toolent') ne '' ) ? 0 : 1);
			push(@sets,( $cgi->value('editor_toolhig') ne '' ) ? 0 : 1);
			foreach my $tool ('first','second') {
				my $label = ($tool eq 'first') ? 'editor_tool' : 'editor_extool';
				my $num = $self->default_tooloption($tool);
				for (my $i=0;$i<$num;$i++) {
					push(@sets,( $cgi->value($label . $i) ne '' ) ? 0 : 1);
					my $elem = sb::Text->entitize($cgi->value($label . $i . '_elem'));
					my $attr = sb::Text->entitize($cgi->value($label . $i . '_opt'));
					my $icon = sb::Text->entitize($cgi->value($label . $i . '_icon'));
					$ext .= $self->_sanitize_text($elem);
					$ext .= '[' . $self->_sanitize_text($attr) . ']' if ($attr ne '');
					$ext .= ':' . $icon . "\n";
				}
			}
			$user->set_option('edit_tool'=>join('',@sets));
			$user->ext($ext);
			last SWITCH_TYPE;
		};
		/^mail$/ && do {
			$user->notice(int($cgi->value('editor_notice')));
			$user->mail(sb::Text->entitize($cgi->value('user_mail')));
			last SWITCH_TYPE;
		};
	}
	sb::Data->update($user);
	return $self->_open_setting('message'=>$lang->string('parts_confcomp'));
}
sub _open_setting {
	my $self = shift;
	my %param = ( 'message' => '', @_ );
	my $cgi = sb::Interface->get;
	my $cms = sb::TemplateManager->new($self->load_template('file'=>TEMPLATE));
	my $user = $self->{'user'};
	my $type = $cgi->value('__type');
	$type = DEFAULT_TYPE if (!$mEditorType{$type});
	$self->{'cat'} = { sb::Data->load_as_hash('Category') };
	$self->common_template_parts($cms);
	SWITCH_TYPE: {
		$_ = $type;
		/^basic$/ && do {
			my %option;
			foreach my $key ($user->get_option_keys) {
				next if ($key eq 'status' or $key eq 'edit_tool');
				$option{$key} = $user->get_option($key);
			}
			{ # テキストフォーマット(追加分)
				my $selector = '';
				my @filters  = sb::Plugin->get_text_filter;
				foreach my $name (@filters) {
					$selector .= '<option value="' . $name . '"';
					$selector .= ' selected="selected"' if ($option{'format'} eq $name);
					$selector .= '>' . $name . '</option>';
				}
				$cms->num(0);
				$cms->tag('sb_editor_extra_format'=>$selector);
			}
			$cms->num(0);
			foreach my $key (keys(%option)) {
				next if ($option{$key} !~ /^\d+$/);
				$cms->tag('sb_editor_' . $key . '_' . $option{$key} => 'selected="selected"');
			}
			my %cat = sb::Data->load_as_hash('Category');
			$cms->tag('sb_editor_category'=>
				'<option value="none">' . sb::Language->get->string('parts_no_cat') . '</option>' .
				$self->category_selector(
					'cat' => [ sort { $b->order <=> $a->order } values(%{$self->{'cat'}}) ],
					'now' => $user->cat,
				)
			);
			my $selector = '';
			foreach my $style ($self->_load_styleset) {
				$selector .= '<option value="' . $style . '"';
				$selector .= ' selected="selected"' if ($user->ad_css eq $style);
				$selector .= '>' . $style . '</option>';
			}
			$cms->num(0);
			$cms->tag('sb_editor_styleset'=>$selector);
			if ($self->{'user'}->stat == 0) { # list for update ping urls
				my @ping_list = split('\\n',sb::Config->get->value('conf_edit_ping'));
				$cms->num(0);
				$cms->tag('sb_editor_pinglist'=>join("\n",@ping_list));
				$cms->block('sb_editor_admin'=>1);
			}
			last SWITCH_TYPE;
		};
		/^tags$/ && do {
			$self->display_toolicons(
				'cms'  => $cms,
				'opt'  => $user->get_option('edit_tool'),
				'set'  => $user->ext,
				'mode' => 'conf',
			);
			last SWITCH_TYPE;
		};
		/^mail$/ && do {
			my $weblog = sb::Data->load('Weblog','id'=>0);
			if ($weblog->stype ne '') {
				$cms->num(0);
				$cms->tag('sb_editor_notice_1'=>'selected="selected"') if ($user->notice);
				$cms->block('sb_editor_notice'=>1);
			}
			$cms->num(0);
			$cms->tag('sb_user_mail'=>$user->mail);
			last SWITCH_TYPE;
		};
	}
	$cms->num(0);
	$cms->tag('sb_selected_type' => $type);
	$cms->tag('sb_editor_menu_' . $type => 'class="current"');
	$cms->tag('sb_form_class' => $mEditorType{$type}->{'form'});
	$cms->block('sb_editor_submit' => $mEditorType{$type}->{'submit'});
	$cms->block('sb_editor_' . $type => 1);
	if ($param{'message'} ne '') { # 処理通知
		$cms->num(0);
		$cms->tag('sb_process_message'=>$param{'message'});
		$cms->block('sb_editor_message'=>1);
	}
	return sb::Interface->get->head('type'=>'text/html') . $self->set_main($cms->output);
}
# ==================================================
# // private functions - for editor settings
# ==================================================
sub _sanitize_text {
	my $self = shift;
	my $text = shift;
	$text =~ s/:/&#58;/g;
	$text =~ s/\[/&#91;/g;
	$text =~ s/\]/&#93;/g;
	$text =~ s/\'/&#39;/g;
	return($text);
}
sub _load_styleset {
	my $self = shift;
	my $list = $self->load_template(
		'dir'  => sb::Config->get->value('dir_temp'),
		'file' => STYLESET_FILE
	);
	return split("\n",$list);
}
1;
__END__
