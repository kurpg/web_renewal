# sb::Admin::Config - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Admin::Config;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.02';
# 0.02 [2005/06/29] added link to rebuilding into the message after changing configuration.
# 0.01 [2005/06/07] changed _open_config to change thumnail setting correctly.
# 0.00 [2005/04/09] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Data ();
use sb::Config ();
use sb::Plugin ();
use sb::Interface ();
use sb::Admin::Entry ();
@ISA = qw( sb::Admin::Entry );
# ==================================================
# // declaration for constant value
# ==================================================
sub TEMPLATE      (){ 'config.html' };
sub DEFAULT_TYPE  (){ 'display' };
sub PLUGIN_LINK   (){ '<a href="%s" target="_blank">%s</a>' };
sub PLUGIN_NONAME (){ '-' };
sub PLUGIN_DETAIL (){ '<dfn title="%s">%s</dfn>' };
# ==================================================
# // declaration for class member
# ==================================================
my %mConfigType = (
	'display'  => {'submit'=>1,},
	'basic'    => {'submit'=>1,},
	'plugin'   => {'submit'=>0,},
	'mail'     => {'submit'=>1,},
);
my %mConfigItems = (
	'disp' => ['entry_disp','newent_disp','com_disp','tb_disp','aws_disp',],
	'sort' => ['page_disp','search_disp','entry_sort','archive_sort','com_sort','tb_sort',],
	'base' => ['srv_base','dir_base','dir_log','dir_img',],
);
# ==================================================
# // public functions - callback
# ==================================================
sub callback { # コールバック
	my $self = shift;
	return ( $self->{'regi'} ) 
		? $self->_save_config(@_)
		: $self->_open_config(@_);
}
# ==================================================
# // private functions - main routine
# ==================================================
sub _save_config {
	my $self = shift;
	my %param = ( 'message' => '', @_ );
	my $blog = sb::Data->load('Weblog','id'=>0);
	my $conf = sb::Config->get;
	my $cgi  = sb::Interface->get;
	my $lang = sb::Language->get;
	my $msg  = '';
	SWITCH_TYPE: {
		$_ = $cgi->value('__type');
		/^display$/ && do {
			$blog->title(sb::Text->entitize($cgi->value('blog_title')));
			$blog->text(sb::Text->entitize($cgi->value('blog_desc')));
			foreach my $key (@{$mConfigItems{'disp'}}) {
				my $value = int($cgi->value($key));
				$value = 1 if ($value <= 0);
				$conf->value('conf_' . $key => $value);
			}
			foreach my $key (@{$mConfigItems{'sort'}}) {
				$conf->value('conf_' . $key => int($cgi->value($key)));
			}
			sb::Data->update($blog);
			last SWITCH_TYPE;
		};
		/^basic$/ && do {
			$conf->value('conf_entry_archive'=>$cgi->value('entry_archive'));
			$conf->value('conf_imagename'=>int($cgi->value('imagename')));
			if ($cgi->value('thumbcheck') ne '') {
				$conf->value('conf_thumbcheck'=>int($cgi->value('thumbcheck')));
			}
			if ($cgi->value('thumbsize') ne '') {
				my $value = int($cgi->value('thumbsize'));
				$value = 0 if ($value <= 0);
				$conf->value('conf_thumbsize'=>$value);
			}
			foreach my $key (@{$mConfigItems{'base'}}) {
				my $value = &_check_dir($cgi->value($key));
				$conf->value('conf_' . $key => $value);
			}
			$conf->value('conf_timezone' => $cgi->value('tz_hour') . $cgi->value('tz_min'));
			last SWITCH_TYPE;
		};
		/^plugin$/ && do {
			my @plugins = split("\0",$cgi->value('use'));
			my $setting = '';
			foreach my $plugin (@plugins) {
				$plugin =~ s/\[/&#91;/g;
				$plugin =~ s/\]/&#93;/g;
				$setting .= '[' . $plugin . ']';
			}
			$blog->plugin($setting);
			sb::Data->update($blog);
			return $cgi->head('location'=>$self->get_script_path . '?__mode=config&__type=plugin&change=on');
		};
		/^mail$/ && do {
			$blog->stype($cgi->value('sendmail'));
			$blog->smtp($cgi->value('smtp_address'));
			$blog->psrv($cgi->value('popserver'));
			$blog->pacc($cgi->value('popacount'));
			$blog->ppass($cgi->value('poppassword'));
			$blog->psubj($cgi->value('popsubject'));
			sb::Data->update($blog);
			last SWITCH_TYPE;
		};
	}
	$conf->store;
	$msg = $lang->string('parts_confcomp');
	if ($cgi->value('__type') ne 'mail') {
		$msg .= $lang->string('parts_needmake');
		$msg .= sprintf($lang->string('parts_link_bld'),$self->get_script_path);
	}
	return $self->_open_config('message'=>$msg);
}
sub _open_config {
	my $self = shift;
	my %param = ( 'message' => '', @_ );
	my $cgi  = sb::Interface->get;
	my $cms  = sb::TemplateManager->new($self->load_template('file'=>TEMPLATE));
	my $blog = sb::Data->load('Weblog','id'=>0);
	my $conf = sb::Config->get;
	my $type = $cgi->value('__type');
	$type = DEFAULT_TYPE if (!$mConfigType{$type});
	$cms->num(0);
	SWITCH_TYPE: {
		$_ = $type;
		/^display$/ && do {
			$cms->tag('sb_blog_title'=>$blog->title);
			$cms->tag('sb_blog_desc'=>$blog->text);
			foreach my $key (@{$mConfigItems{'disp'}}) {
				$cms->tag('sb_' . $key => $conf->value('conf_' . $key));
			}
			foreach my $key (@{$mConfigItems{'sort'}}) {
				$cms->tag('sb_' . $key => 'selected="selected"') if ($conf->value('conf_' . $key));
			}
			last SWITCH_TYPE;
		};
		/^basic$/ && do {
			my $selector = '';
			foreach my $mode ( @{$conf->value('setup_entry_archive')} ) {
				my $label = sb::Language->get->string('entryarchive_' . $mode);
				$label .= ' (' . $mode . ')';
				$selector .= '<option value="' . $mode . '"';
				$selector .= ' selected="selected"' if ($mode eq $conf->value('conf_entry_archive'));
				$selector .= '>' . $label . '</option>';
			}
			$cms->tag('sb_entry_archive'=>$selector);
			if ( eval('require Image::Magick') ) {
				$cms->num(0);
				$cms->tag('sb_thumbsize'=>$conf->value('conf_thumbsize'));
				$cms->tag('sb_thumbcheck'=>'selected="selected"') if ($conf->value('conf_thumbcheck'));
				$cms->block('sb_config_thumb'=>1);
			}
			$cms->tag('sb_imagename'=>'selected="selected"') if ($conf->value('conf_imagename'));
			foreach my $key (@{$mConfigItems{'base'}}) {
				$cms->tag('sb_' . $key => $conf->value('conf_' . $key));
			}
			$self->timezone_selector(
				'cms'     => $cms,
				'tag'     => 'sb_config_zone',
				'current' => $conf->value('conf_timezone'),
			);
			last SWITCH_TYPE;
		};
		/^plugin$/ && do {
			my %plugin = sb::Plugin->get_list;
			my $num = 0;
			foreach my $name ( keys(%plugin) ) {
				my $author = ($plugin{$name}->{'author'} ne '') ? $plugin{$name}->{'author'} : PLUGIN_NONAME;
				if ($plugin{$name}->{'detail'} =~ /s?https?:\/\/[-_.!~*\'()a-zA-Z0-9;\/?:\@&=+\$,%#]+/) { # '
					$author = sprintf(PLUGIN_LINK,$plugin{$name}->{'detail'},$author);
				}
				my $plugin_name = $plugin{$name}->{'name'};
				if ($plugin{$name}->{'text'} ne '') {
					$plugin_name = sprintf(PLUGIN_DETAIL,$plugin{$name}->{'text'},$plugin_name);
				}
				$cms->num($num);
				$cms->tag('sb_plugin_file'=>$name);
				$cms->tag('sb_plugin_version'=>$plugin{$name}->{'version'});
				$cms->tag('sb_plugin_name'=>$plugin_name);
				$cms->tag('sb_plugin_auth'=>$author);
				$cms->tag('sb_plugin_type'=>$plugin{$name}->{'type'});
				$cms->tag('sb_plugin_flag'=>'checked="checked"') if (!&sb::Plugin::_ignore_plugin($name));
				$cms->tag('sb_list_class'=>($num % 2) ? 'odd' : 'even');
				$num++;
			}
			if ($num > 0) {
				$cms->block('sb_config_plugin_list'=>$num);
				$cms->block('sb_config_plugin_select'=>1);
			} else {
				$cms->block('sb_config_noplugin'=>1);
			}
			if ($cgi->value('change') eq 'on') {
				$param{'message'}  = sb::Language->get->string('parts_confcomp');
				$param{'message'} .= sb::Language->get->string('parts_needmake');
				$param{'message'} .= sprintf(sb::Language->get->string('parts_link_bld'),$self->get_script_path);
			}
			last SWITCH_TYPE;
		};
		/^mail$/ && do {
			$cms->tag('sb_sendmail_' . $blog->stype =>'selected="selected"') if ($blog->stype ne '');
			$cms->tag('sb_smtp'=>sb::Text->entitize($blog->smtp));
			$cms->block('sb_config_smtp'=>1) if ( eval('require Net::SMTP;') );
			if ( eval('require Net::POP3;') ) {
				$cms->num(0);
				$cms->tag('sb_popserver'   =>sb::Text->entitize($blog->psrv));
				$cms->tag('sb_popacount'   =>sb::Text->entitize($blog->pacc));
				$cms->tag('sb_poppassword' =>sb::Text->entitize($blog->ppass));
				$cms->tag('sb_popsubject'  =>sb::Text->entitize($blog->psubj));
				$cms->block('sb_config_pop'=>1);
			}
			last SWITCH_TYPE;
		};
	}
	$cms->num(0);
	$cms->tag('sb_selected_type' => $type);
	$cms->tag('sb_config_menu_' . $type => 'class="current"');
	$cms->block('sb_config_submit' => $mConfigType{$type}->{'submit'});
	$cms->block('sb_config_' . $type => 1);
	if ($param{'message'} ne '') { # 処理通知
		$cms->num(0);
		$cms->tag('sb_process_message'=>$param{'message'});
		$cms->block('sb_config_message'=>1);
	}
	$self->common_template_parts($cms);
	return sb::Interface->get->head('type'=>'text/html') . $self->set_main($cms->output);
}
# ==================================================
# // private functions - for config screen
# ==================================================
sub _check_dir {
	$_[0] .= '/' if ($_[0] !~ /\/$/);
	return($_[0]);
}
1;
__END__
