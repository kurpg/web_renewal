# sb::Admin::Template - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Admin::Template;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.11';
# 0.11 [2007/05/04] changed _check_filename to fix a bug
# 0.10 [2007/04/29] added _check_filename
# 0.09 [2006/09/30] changed _additional_dateformat to check linefeed code
# 0.08 [2006/09/26] supported additional date format
# 0.07 [2005/10/19] changed _save_template to call build_css directly
# 0.06 [2005/10/18] changed _save_template to pass TemplateManager object to builder
# 0.05 [2005/10/01] added _convert_template to implement new template spec
# 0.04 [2005/08/12] changed import_template to convert character code correctly
# 0.03 [2005/07/15] added import_template to allow to call externally
# 0.02 [2005/07/11] changed config variable "srv_cgi" to "conf_srv_cgi"
# 0.01 [2005/06/29] changed interface of changing current template
# 0.00 [2005/04/09] generate

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Mailer ();
use sb::Config ();
use sb::Language ();
use sb::Interface ();
use sb::Build ();
use sb::Admin::List ();
@ISA = qw( sb::Admin::List );
# ==================================================
# // declaration for constant value
# ==================================================
sub TEMPLATE     (){ 'template.html' };
sub DEFAULT_TYPE (){ 'main' };
sub PARTS_DIR    (){ '_parts/' };
sub FLAG_IMAGE   (){ 'flag.gif' };
sub DENIED_CHECK (){ '-' };
sub PARTS_LINK   (){ '<li class="%s"><a href="%s" target="_blank">%s</a></li>' };
# ==================================================
# // declaration for class member
# ==================================================
my %mTemplateConfig = (
	'temp' => ['archive_temp','profile_temp','mobile_temp','css_change',],
	'time' => ['entry_date','entry_time','msg_time','dateinlist','archivelist','time_lang',],
);
# ==================================================
# // public functions - callback
# ==================================================
sub callback
{
	my $self = shift;
	return ( $self->{'regi'} ) 
		? $self->_save_template(@_)
		: $self->_open_template(@_);
}
# ==================================================
# // private functions - utilities
# ==================================================
sub import_template
{
	my $self = shift;
	my %param = (
		'cont' => undef,
		'time' => undef,
		@_
	);
	$param{'cont'} =~ s/\x0D\x0A|\x0D|\x0A/\n/g; # unify linefeed
	my %elem = ();
	my $lang = sb::Language->get;
	my $conf = sb::Config->get;
	my $parser = sb::Mailer->new;
	my $contents = $parser->text_parse($param{'cont'});
	$elem{'name'} = $parser->extract_head($contents->{'head'},'Subject');
	if ($elem{'name'} ne '')
	{
		$lang->checkcode($elem{'name'},'jis');
		$elem{'name'} = $lang->convert($elem{'name'},$lang->charcode);
		$elem{'name'} = sb::Text->entitize($elem{'name'});
	}
	else
	{
		$elem{'name'} = $lang->string('parts_noname');
	}
	$elem{'files'} = '';
	if ($contents->{'boundary'})
	{
		my $dir = $conf->value('conf_dir_base') . $conf->value('dir_style');
		my $parts = $parser->multipart($contents);
		foreach my $part ( @{$parts} )
		{
			if ($part->{'name'} eq 'base.html')
			{
				$elem{'main'} = $part->{'body'};
			}
			elsif ($part->{'name'} eq 'style.css')
			{
				$elem{'css'} = $part->{'body'};
			}
			elsif ($part->{'name'} eq 'entry.html')
			{
				$elem{'entry'} = $part->{'body'};
			}
			elsif ($part->{'name'} ne '')
			{ # output parts
				my $file = $self->_check_filename($dir,$part->{'name'});
				if ($file ne '')
				{
					open(TMPOUT,">$file");
					binmode(TMPOUT);
					print TMPOUT $part->{'body'};
					close(TMPOUT);
					chmod($conf->value('basic_file_attr'),$file);
					$elem{'files'} .= $part->{'name'} . ',' if (-e $file);
				}
			}
		}
		$elem{'info'} = $parts->[0]->{'body'}; # template information
		foreach my $key ('main','css','entry','info')
		{ # convert text for each part
			$elem{$key} =~ s/\x0D\x0A|\x0D|\x0A/\n/g;
			if ($key eq 'info')
			{
				$elem{$key} =~ s/^\.\./\./;
				$elem{$key} =~ s/\n\.\./\n\./g;
				$lang->checkcode($elem{$key},'jis');
			}
			else
			{
				$elem{$key} =~ s/\.\/__template\//\{site_parts\}/g; # convert path for parts
				$lang->checkcode($elem{$key});
			}
			$elem{$key} = $lang->convert($elem{$key},$lang->charcode);
		}
		$elem{'use'} = 0;
		$elem{'gen'} = $param{'time'};
		$elem{'mod'} = $param{'time'};
		if ($lang->code ne 'ja')
		{
			$elem{'main'} = &_convert_template($elem{'main'});
			$elem{'css'} = &_convert_template($elem{'css'});
			$elem{'entry'} = &_convert_template($elem{'entry'});
		}
		my $new = sb::Data->add('Template',%elem);
		sb::Data->update($new) if ($new);
		return( $new );
	}
	return;
}
sub _convert_template
{
	my $text = shift;
	$text =~ s/\{(\w+?)\}/<sb_$1\/>/g;
	$text =~ s/<\!-- BEGIN (\w+) -->/<sb_$1_>/g;
	$text =~ s/<\!-- END (\w+) -->/<\/sb_$1_>/g;
	return $text;
}
# ==================================================
# // private functions - main routine
# ==================================================
sub _save_template
{
	my $self = shift;
	my %param = ( 'message' => '', @_ );
	my $cgi  = sb::Interface->get;
	my $lang = sb::Language->get;
	my $conf = sb::Config->get;
	my $type = $cgi->value('__type');
	my $msg  = '';
	my $tid  = $cgi->value('tid');
	if ($type eq 'main')
	{
		if ($self->{'regi'} eq 'change' and $cgi->value('del') ne '')
		{
			my @sels = split("\0",$cgi->value('sel'));
			my @tmps = sb::Data->load('Template','cond'=>{'id'=>\@sels});
			foreach my $tmp (@tmps)
			{
				next if ($tmp->use);
				$tmp->erase;
			}
			sb::Data->update(@tmps) if (@tmps);
			$msg = ($#tmps + 1) . $lang->string('parts_deleted');
		}
		elsif ($self->{'regi'} eq 'change' and $cgi->value('sel') ne '')
		{
			my $old_id = sb::Data->load('Template','cond'=>{'use'=>1})->id;
			my $new_id = $cgi->value('use');
			if ($new_id ne '' and $new_id ne $old_id)
			{
				my $old = sb::Data->load('Template','id'=>$old_id);
				my $new = sb::Data->load('Template','id'=>$new_id);
				if ($old and $new)
				{
					$old->use(0);
					$new->use(1);
					sb::Build->build_css(sb::TemplateManager->new($new->css));
					sb::Data->update($old,$new);
					$msg  = $lang->string('parts_temp_sel');
					$msg .= $lang->string('parts_temp_css');
					$msg .= $lang->string('parts_needmake');
					$msg .= sprintf($lang->string('parts_link_bld'),$self->get_script_path);
				}
			}
		}
		else
		{
			my $temp = sb::Data->load('Template','id'=>$tid);
			$self->process_message($lang->string('error_unknown')) if (!$temp);
			if ($self->{'regi'} eq 'add')
			{ # save as ...
				my $name = sb::Text->entitize($cgi->value('temp_name'));
				$name = $temp->name if ($name eq '');
				my $new = sb::Data->add('Template',
					'use'   => 0,
					'name'  => $name,
					'gen'   => $self->{'time'},
					'mod'   => $self->{'time'},
					'main'  => $temp->main,
					'css'   => $temp->css,
					'entry' => $temp->entry,
					'info'  => $temp->info,
				);
				sb::Data->update($new) if ($new);
				$msg = $lang->string('parts_temp_add');
				$tid = undef;
			}
			elsif ($self->{'regi'} eq 'base')
			{ # save base html part
				$temp->main($cgi->value('template_main'));
				$msg  = $lang->string('parts_tempcomp');
				$msg .= $lang->string('parts_needmake');
				$msg .= sprintf($lang->string('parts_link_bld'),$self->get_script_path);
			}
			elsif ($self->{'regi'} eq 'css')
			{ # save css part
				$temp->css($cgi->value('template_css'));
				sb::Build->build_css(sb::TemplateManager->new($temp->css)) if ($temp->use);
				$msg = $lang->string('parts_temp_css');
			}
			elsif ($self->{'regi'} eq 'entry')
			{ # save entry html part
				$temp->entry($cgi->value('template_entry'));
				$msg = $lang->string('parts_tempcomp');
				if ($conf->value('conf_entry_archive') eq 'Individual')
				{
					$msg .= $lang->string('parts_needmake');
					$msg .= sprintf($lang->string('parts_link_bld'),$self->get_script_path);
				}
			}
			if ($self->{'regi'} ne 'add')
			{
				$temp->mod($self->{'time'});
				sb::Data->update($temp);
			}
 		}
	}
	elsif ($type eq 'config')
	{
		foreach my $key (@{$mTemplateConfig{'temp'}})
		{
			$conf->value('conf_' . $key => int($cgi->value($key)) );
		}
		foreach my $key (@{$mTemplateConfig{'time'}})
		{
			# my $value = sb::Text->entitize($cgi->value($key));
			my $value = $cgi->value($key);
			$conf->value('conf_' . $key => $value);
		}
		$conf->store;
		$msg  = $lang->string('parts_confcomp');
		$msg .= $lang->string('parts_needmake');
		$msg .= sprintf($lang->string('parts_link_bld'),$self->get_script_path);
	}
	elsif ($type eq 'import' and $cgi->value('temp_package') ne '')
	{
		if ($self->import_template('cont' => $cgi->value('temp_package'),'time' => $self->{'time'}))
		{
			$msg = $lang->string('parts_temp_add');
			$type = DEFAULT_TYPE;
		}
		else
		{
			$msg = $lang->string('error_unknown');
		}
	}
	return $self->_open_template('message'=>$msg,'type'=>$type,'tid'=>$tid);
}
sub _open_template
{
	my $self = shift;
	my %param = (
		'message' => '',
		'type'    => sb::Interface->get->value('__type'),
		'tid'     => sb::Interface->get->value('tid'),
		@_
	);
	my $cgi  = sb::Interface->get;
	my $cms  = sb::TemplateManager->new($self->load_template('file'=>TEMPLATE));
	my $type = $param{'type'} || DEFAULT_TYPE;
	my $tid  = $param{'tid'};
	my @tmps = ();
	if ($self->{'mode'} eq 'edittemp')
	{ # edit current template
		$tid = sb::Data->load('Template','cond'=>{'use'=>1})->id;
		$self->{'mode'} = 'template';
		$type = DEFAULT_TYPE;
	}
	if ($type eq 'main')
	{
		my @tmps = sb::Data->load('Template',
			'sort'  => 'mod',
			'order' => 1,
			'id'    => ( $tid eq '' ) ? undef : $tid,
		);
		$self->listmain(
			'template' => $cms,
			'block'    => 'sb_template_list',
			'objects'  => \@tmps,
			'tags'     => {
				'sb_temp_id'   => 'id',
				'sb_temp_name' => 'name',
				'sb_temp_info' => \&_display_info_link,
				'sb_temp_view' => \&_display_preview,
				'sb_temp_gen'  => 'gen',
				'sb_temp_mod'  => 'mod',
				'sb_temp_use'  => \&_display_current,
				'sb_temp_del'  => sub { return ($tid ne '') ? DENIED_CHECK : &_display_checkbox(@_) },
				'sb_site_cgi'  => sub { $self->get_script_path },
				'sb_site_template' => sub { sb::Config->get->value('srv_temp') . PARTS_DIR },
			},
		);
		if ($tid eq '')
		{
			my $current_template = '';
			foreach my $tmp (@tmps)
			{
				$current_template .= '<option value="' . $tmp->id . '"';
				$current_template .= ' selected="selected"' if ($tmp->use);
				$current_template .= '>' . $tmp->name . '</option>' . "\n";
			}
			$cms->num(0);
			$cms->tag('sb_current_templates'=>$current_template);
		}
		if ($tid ne '' and $tmps[0])
		{
			$cms->num(0);
			if ($cgi->value('disp') eq 'info')
			{
				my $text = sb::Text->entitize($tmps[0]->info);
				$cms->tag('sb_temp_information'=>sb::Text->format('text'=>$text,'form'=>2));
				$cms->block('sb_template_info'=>1);
				if ($tmps[0]->files ne '')
				{
					my $dir = sb::Config->get->value('conf_srv_base') . sb::Config->get->value('dir_style');
					my @parts = split(',',$tmps[0]->files);
					my $list = '';
					for (my $i=0;$i<@parts;$i++)
					{
						$list .= sprintf(PARTS_LINK . "\n",
							($i % 2) ? 'odd' : 'even',
							$dir . $parts[$i],
							$parts[$i]
						);
					}
					$cms->tag('sb_temp_partslist'=>$list);
					$cms->block('sb_template_parts'=>1);
				}
			}
			else
			{
				$cms->tag('sb_temp_id'=>$tmps[0]->id);
				$cms->tag('sb_temp_main'=>sb::Text->entitize($tmps[0]->main));
				$cms->tag('sb_temp_css'=>sb::Text->entitize($tmps[0]->css));
				$cms->tag('sb_temp_entry'=>sb::Text->entitize($tmps[0]->entry));
				$cms->block('sb_template_edit'=>1);
			}
		}
		else
		{
			$cms->block('sb_template_select'=>1);
		}
	}
	elsif ($type eq 'config')
	{
		my $conf = sb::Config->get;
		$cms->num(0);
		foreach my $key (@{$mTemplateConfig{'temp'}})
		{
			next if ($key eq 'css_change');
			my $value = $conf->value('conf_' . $key);
			$self->template_selector(
				'cms' => $cms,
				'tag' => 'sb_' . $key,
				'now' => $value,
			);
			$cms->tag('sb_' . $key . '_id'=>'&amp;tid=' . $value) if ($value > -1);
		}
		$cms->tag('sb_css_change'=>'selected="selected"') if ($conf->value('conf_css_change'));
		foreach my $key (@{$mTemplateConfig{'time'}})
		{
			next if ($key eq 'time_lang');
			my $value = sb::Text->entitize($conf->value('conf_' . $key));
			$cms->tag('sb_' . $key => $value);
		}
		$cms->tag('sb_time_lang_' . $conf->value('conf_time_lang')=>'selected="selected"');
		$self->_additional_dateformat($cms);
	}
	$cms->num(0);
	$cms->tag('sb_selected_type' => $type);
	$cms->tag('sb_submenu_template_' . $type => 'class="current"');
	$cms->block('sb_template_' . $type => 1);
	$cms->block('sb_template_importable'=>1) if ($self->_check_style_dir);
	if ($param{'message'} ne '')
	{ # message
		$cms->num(0);
		$cms->tag('sb_process_message'=>$param{'message'});
		$cms->block('sb_template_message'=>1);
	}
	$self->common_template_parts($cms);
	return sb::Interface->get->head('type'=>'text/html') . $self->set_main($cms->output);
}
# ==================================================
# // private functions - for template screen
# ==================================================
sub _check_style_dir
{
	my $self = shift;
	my $dir = sb::Config->get->value('conf_dir_base') . sb::Config->get->value('dir_style');
	return (-d $dir and -r $dir and -w $dir)
}
sub _display_info_link
{
	my $self = shift;
	my $obj  = shift;
	return() if ($obj->info eq '');
	my $path = $self->get_script_path . '?__mode=template&amp;disp=info&amp;tid=';
	return '<a href="' . $path . $obj->id . '">' . sb::Language->get->string('parts_tmpinfo') . '</a>';
}
sub _display_preview
{
	my $self = shift;
	my $obj  = shift;
	my $viewpath = sb::Config->get->value('conf_srv_cgi') . sb::Config->get->value('basic_sb');
	return $viewpath . '?tid=' . $obj->id;
}
sub _display_current
{
	my $self = shift;
	my $obj  = shift;
	my $parts = sb::Config->get->value('srv_temp') . PARTS_DIR . FLAG_IMAGE;
	return ( !$obj->use )
	? DENIED_CHECK
	: '<img src="' . $parts . '" height="20" width="20" alt="in use" />';
}
sub _display_checkbox
{
	my $self = shift;
	my $obj  = shift;
	return ( !$obj->use )
	? '<input type="checkbox" name="sel" value="' . $obj->id . '" onclick="switchList(this)" />'
	: DENIED_CHECK;
}
sub _additional_dateformat
{
	my $self = shift;
	my $cms = shift;
	my $dir = sb::Config->get->value('conf_dir_base') . sb::Config->get->value('dir_style');
	my @files = ();
	opendir(TEMPDIR,$dir);
	foreach my $check ( readdir(TEMPDIR) )
	{
		push(@files,$check) if ($check =~ /\.dateform$/);
	}
	closedir(TEMPDIR);
	my $array  = '<script type="text/javascript">' . "\n" . '// <![CDATA[' . "\n";
	my $option = '';
	foreach my $name (@files)
	{
		my $file = $dir . $name;
		$name =~ s/\.dateform$//;
		my $prefix = "sbTimeSet['" . $name . "']";
		open(TEMPFILE,"<$file") or next;
		my @lines = <TEMPFILE>;
		my $tmp = join('',@lines);
		$tmp =~ s/\x0D\x0A|\x0D|\x0A/\n/g;
		@lines = split("\n",$tmp);
		my $label = sb::Text->entitize(shift(@lines));
		$array .= $prefix . ' = new Array();' . "\n";
		foreach my $line ( @lines )
		{
			my ($key,$val) = split(/\t/,$line,2);
			next if ($key =~ /\W/);
			$val =~ s/\\/\\\\/g;
			$val =~ s/\'/\\\'/g;
			$val =~ s/\//\\\//g;
			$array .= $prefix . '.' . $key . ' = \'' . $val . '\';' . "\n";
		}
		$option .= '<option value="' . $name . '">' . $label . '</option>';
		close(TEMPFILE);
	}
	$cms->num(0);
	$cms->tag('sb_additional_date_array'=>$array . '// ]]>' . "\n" . '</script>');
	$cms->tag('sb_additional_date_option'=>$option);
}
sub _check_filename
{
	my $self = shift;
	my $base = shift;
	my $name = shift;
	my $dir  = '';
	if ($name =~ m!(.+)/(.+)!)
	{ # name includes dir name
		$dir  = $1;
		$name = $2;
	}
	if ($dir ne '' and $dir =~ /\w+/)
	{
		$base .= $dir . '/';
		if (!-e $base)
		{ # not exists, so we should create it.
			eval{ umask(0) };
			mkdir($base,sb::Config->get->value('basic_dir_attr'));
		}
	}
	elsif ($dir ne '')
	{ # invalid dir name
		return;
	}
	return if (!-d $base); # make sure dir exists
	return if ($name !~ /[a-zA-Z0-9\-\._]+/); # invalid file name
	return($base . $name); # verified!
}
1;
__END__
