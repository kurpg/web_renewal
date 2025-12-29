# sb::Build - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Build;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.08';
# 0.08 [2007/05/11] changed build_category_index and build_monthly_archive
# 0.07 [2006/02/03] changed build_feedfile
# 0.06 [2005/10/18] changed _initialize to load templates as instances of TemplateManager
# 0.05 [2005/08/03] changed build_top_page to sort entries correctly
# 0.04 [2005/08/02] changed set_latest_entries to get entries for feeds
# 0.03 [2005/07/16] changed build_javascript, _script_tag, _generate_javascript to handle list type block correctly
# 0.02 [2005/07/11] changed config variable "srv_cgi" to "conf_srv_cgi"
# 0.01 [2005/07/08] added build_cookie_js
# 0.00 [2005/02/02] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Language ();
use sb::Config ();
use sb::Data ();
use sb::App ();
use sb::App::Feed ();
use sb::Content ();
# ==================================================
# // declaration for constant value
# ==================================================
sub SCRIPT_TAG         (){ '<script type="text/javascript" charset="%s" src="%s"></script>' };
sub SUBCATEGORY_PREFIX (){ 'cat' };
sub LIST_TEMPLATE      (){ "<!-- BEGIN %s -->\n{%s}\n<!-- END %s -->\n" };
sub FUNCS_INITIALIZED  (){ 'initialized' };
sub COOKIE_JS_TEMP     (){ 'default_script.js' };
# ==================================================
# // declaration for class member
# ==================================================
my %mListScripts = (
	'link_list'             => {'js'=>'link.js',   'block'=>'link',            },
	'user_list'             => {'js'=>'user.js',   'block'=>'profile',         },
	'recent_comment_list'   => {'js'=>'comment.js','block'=>'recent_comment',  },
	'recent_trackback_list' => {'js'=>'tb.js',     'block'=>'recent_trackback',},
	'latest_entry_list'     => {'js'=>'entry.js',  'block'=>'latest_entry',    },
	'category_list'         => {'js'=>'cat.js',    'block'=>'category',        },
	'archives_list'         => {'js'=>'arc.js',    'block'=>'archives',        },
	'calendar'              => {'js'=>'cal1.js',   'block'=>'calendar',        },
	'calendar2'             => {'js'=>'cal2.js',   'block'=>'calendar',        },
	'calendar_vertical'     => {'js'=>'calv.js',   'block'=>'calendar',        },
	'calendar_horizontal'   => {'js'=>'calh.js',   'block'=>'calendar',        },
);
my %mFeedFile = (
	'rss'  => 'index.rdf',
	'atom' => 'atom.xml',
);
# ==================================================
# // constructor
# ==================================================
sub new {
	my $class = shift;
	my $self = {
		'time'      => undef, # [NUM.]current time
		'blog'      => undef, # [OBJ.]weblog data
		'user'      => undef, # [HASH]user data
		'cat'       => undef, # [HASH]category data
		'sortedcat' => undef, # [ARRY]sorted category data
		'entryinfo' => undef, # [HASH]entry information
		'template'  => undef, # [HASH]template data
		'def_temp'  => undef, # [NUM.]default template id
		'ent_funcs' => undef, # [SEL.]flag for callbacks of Individual
		'feedfuncs' => undef, # [SEL.]flag for callbacks of Feeds
		'mainfuncs' => undef, # [SEL.]flag for callbacks of Main
		@_
	};
	$self = bless($self,$class);
	return $self->_initialize;
}
# ==================================================
# // public functions
# ==================================================
sub build_css {
	my $self = shift;
	my $css  = shift;
	my $file = sb::Config->get->value('conf_dir_base') . sb::Config->get->value('file_css');
	$css = $self->{'template'}->{'css'} if (ref($self) and !$css);
	eval {
		open(CSSOUT,">$file") or die(sb::Language->get->string('error_file_open') . $file);
		binmode(CSSOUT);
		print CSSOUT sb::Content->output($css,'mode'=>'css');
		close(CSSOUT);
	};
	return ($@) ? $@ : undef;
}
sub build_entry {
	my $self = shift;
	my $entry = shift;
	my %param = (
		'prev' => undef,
		'next' => undef,
		@_
	);
	return(sb::Language->get->string('error_no_entry')) if (!$entry);
	$self->set_callback_for_entry if (!$self->{'ent_funcs'});
	my $file = $entry->file_path($self->{'cat'});
	eval {
		my $cat = ($entry->cat ne '') ? $self->{'cat'}->{$entry->cat} : undef;
		my ($base,$css) = $self->_check_template('ent',$cat);
		my $info = (defined($param{'prev'}) or defined($param{'next'}))
		         ? {'neighbor'=>{'prev'=>$param{'prev'},'next'=>$param{'next'}}}
		         : undef;
		open(ENTRYOUT,">$file") or die(sb::Language->get->string('error_file_open') . $file);
		binmode(ENTRYOUT);
		print ENTRYOUT sb::Content->output($base,
			'mode'      => 'ent',
			'css'       => $css,
			'id'        => $entry->id,
			'time'      => $self->{'time'},
			'blog'      => $self->{'blog'},
			'user'      => $self->{'user'},
			'cat'       => $self->{'cat'},
			'sortedcat' => $self->{'sortedcat'},
			'entryinfo' => $info,
			'entry'     => [$entry],
			'entry_num' => 1,
			'callback'  => $self->{'ent_funcs'},
		);
		close(ENTRYOUT);
		chmod(sb::Config->get->value('basic_file_attr'),$file);
	};
	return ($@) ? $@ : undef;
}
sub build_monthly_archive {
	my $self = shift;
	my $month = shift;
	return(sb::Language->get->string('error_unknown')) if (!$month);
	my $file = sb::Config->get->value('conf_dir_base') 
	         . sb::Config->get->value('conf_dir_log')
	         . $month
	         . sb::Config->get->value('basic_suffix');
	my %extends = ();
	# $extends{'category'}     = \&_category_list;
	# $extends{'archives'}     = sub { &_script_tag('archives_list',$_[0]); };
	# $extends{'latest_entry'} = sub { &_script_tag('latest_entry_list',$_[0]); };
	eval {
		my ($base,$css) = $self->_check_template('arc',undef);
		open(MONTHLYOUT,">$file") or die(sb::Language->get->string('error_file_open') . $file);
		binmode(MONTHLYOUT);
		print MONTHLYOUT sb::Content->output($base,
			'mode'      => 'arc',
			'css'       => $css,
			'cond'      => $month,
			'time'      => $self->{'time'},
			'blog'      => $self->{'blog'},
			'user'      => $self->{'user'},
			'cat'       => $self->{'cat'},
			'sortedcat' => $self->{'sortedcat'},
			'extend'    => { 'main' => \%extends },
		);
		close(MONTHLYOUT);
		chmod(sb::Config->get->value('basic_file_attr'),$file);
	};
	return ($@) ? $@ : undef;
}
sub build_category_index {
	my $self = shift;
	my $cat_id = shift;
	return(sb::Language->get->string('error_unknown')) if ($cat_id eq '');
	my $cat = $self->{'cat'}->{$cat_id};
	return(sb::Language->get->string('error_unknown')) if (!$cat);
	return(sb::Language->get->string('error_unknown')) if ($cat->dir eq '');
	return(sb::Language->get->string('error_unknown')) if (!$cat->idx);
	my $file = sb::Config->get->value('conf_dir_base') . $cat->dir . sb::Config->get->value('file_index');
	my %extends = ('_main' => \&_category_feeds);
	# $extends{'category'}     = \&_category_list;
	# $extends{'archives'}     = sub { &_script_tag('archives_list',$_[0]); };
	# $extends{'latest_entry'} = sub { &_script_tag('latest_entry_list',$_[0]); };
	eval {
		my ($base,$css) = $self->_check_template('arc',$cat);
		open(CATOUT,">$file") or die(sb::Language->get->string('error_file_open') . $file);
		binmode(CATOUT);
		print CATOUT sb::Content->output($base,
			'mode'      => 'cat',
			'id'        => $cat->id,
			'css'       => $css,
			'time'      => $self->{'time'},
			'blog'      => $self->{'blog'},
			'user'      => $self->{'user'},
			'cat'       => $self->{'cat'},
			'sortedcat' => $self->{'sortedcat'},
			'entryinfo' => $self->{'entryinfo'},
			'extend'    => { 'main' => \%extends },
		);
		close(CATOUT);
		chmod(sb::Config->get->value('basic_file_attr'),$file);
	};
	return ($@) ? $@ : undef;
}
sub build_top_page {
	my $self = shift;
	my $conf = sb::Config->get;
	my $file = $conf->value('conf_dir_base') . $conf->value('file_index');
	$self->set_callback_for_main if (!$self->{'mainfuncs'});
	eval {
		my ($base,$css) = $self->_check_template(undef,undef);
		open(TOPOUT,">$file") or die(sb::Language->get->string('error_file_open') . $file);
		binmode(TOPOUT);
		print TOPOUT sb::Content->output($base,
			'mode'      => 'page',
			'css'       => $css,
			'time'      => $self->{'time'},
			'blog'      => $self->{'blog'},
			'user'      => $self->{'user'},
			'cat'       => $self->{'cat'},
			'sortedcat' => $self->{'sortedcat'},
			'entry'     => ( $conf->value('conf_entry_sort') ) ? $self->{'entry'} : undef,
			'entry_num' => $self->{'entry_num'},
			'entryinfo' => $self->{'entryinfo'},
			'callback'  => $self->{'mainfuncs'},
		);
		close(TOPOUT);
		chmod($conf->value('basic_file_attr'),$file);
	};
	return ($@) ? $@ : undef;
}
sub build_javascript {
	my $self = shift;
	my $type = shift;
	$type ||= 'all'; # default type
	my $dir = sb::Config->get->value('conf_dir_base') . sb::Config->get->value('conf_dir_log');
	my @types = keys( %mListScripts );
	@types = ($type) if ($type ne 'all');
	$self->set_callback_for_main if (!$self->{'mainfuncs'});
	foreach my $type ( @types ) {
		next unless ( defined($mListScripts{$type}) );
		my $block = $mListScripts{$type}->{'block'};
		my $file = $dir . $mListScripts{$type}->{'js'};
		my $cms  = sb::TemplateManager->new(sprintf(LIST_TEMPLATE,$block,$type,$block));
		my $temp = sb::Content->output($cms,
			'time'      => $self->{'time'},
			'blog'      => $self->{'blog'},
			'user'      => $self->{'user'},
			'cat'       => $self->{'cat'},
			'sortedcat' => $self->{'sortedcat'},
			'entry'     => [],
			'entry_num' => 0,
			'entryinfo' => $self->{'entryinfo'},
			'callback'  => $self->{'mainfuncs'},
		);
		&_generate_javascript($file,$temp);
	}
	if ($type eq 'all' or $type eq 'category_list') {
		foreach my $cat ( values(%{$self->{'cat'}}) ) {
			next if ($cat->sub eq '');
			my $file = $dir . SUBCATEGORY_PREFIX . $cat->id . '.js';
			my $cms  = sb::TemplateManager->new(sprintf(LIST_TEMPLATE,'category','subcategory_list','category'));
			my $temp = sb::Content->output($cms,
				'mode'      => 'cat',
				'id'        => $cat->id,
				'time'      => $self->{'time'},
				'blog'      => $self->{'blog'},
				'user'      => $self->{'user'},
				'cat'       => $self->{'cat'},
				'sortedcat' => $self->{'sortedcat'},
				'entry'     => [],
				'entry_num' => 0,
				'entryinfo' => $self->{'entryinfo'},
				'callback'  => $self->{'mainfuncs'},
			);
			&_generate_javascript($file,$temp);
		}
	}
}
sub build_cookie_js {
	my $self  = shift;
	my $force = shift;
	my $conf = sb::Config->get;
	my $file = $conf->value('conf_dir_base') . $conf->value('conf_dir_log') . $conf->value('file_cook');
	return( undef ) if (-s $file and !$force);
	my $temp  = sb::TemplateManager->new(sb::App->load_template('file'=>COOKIE_JS_TEMP));
	my @icons = sb::Data->load('Image','cond'=>{'icon_c'=>1});
	my $icon_list = '';
	foreach my $icon (@icons) {
		$icon_list .= "\t" . 'case \'' . $icon->id . '\': imgSrc = "';
		$icon_list .= $icon->get_url . '"; break;' . "\n";
	}
	$temp->num(0);
	$temp->tag('sb_cookie_tag'=>$conf->value('basic_cooktag'));
	$temp->tag('sb_icon_list'=>$icon_list);
	eval {
		open(COOKIEJS,">$file") or die(sb::Language->get->string('error_file_open') . $file);
		binmode(COOKIEJS);
		print COOKIEJS $temp->output;
		close(COOKIEJS);
		chmod(sb::Config->get->value('basic_file_attr'),$file);
	};
	return ($@) ? $@ : undef;
}
sub build_feedfile {
	my $self = shift;
	my $type = shift;
	$type ||= 'all'; # default type
	my @feeds = ();
	push(@feeds, ($type eq 'all') ? keys(%mFeedFile) : $type );
	my $lang = sb::Language->get;
	my $conf = sb::Config->get;
	$self->set_callback_for_feed if (!$self->{'feedfuncs'});
	foreach my $feed (@feeds) {
		next if ( !defined($mFeedFile{$feed}) );
		my $num = $conf->value('basic_gen_' . $feed);
		my $filebase = $conf->value('conf_dir_log') . $mFeedFile{$feed};
		my $file = $conf->value('conf_dir_base') . $filebase;
		my $temp = sb::App->load_template('file'=>sb::App::Feed->template_name($feed));
		sb::App::Feed->path($conf->value('conf_srv_base') . $filebase);
		$self->set_latest_entries($num) if ($num != $conf->value('conf_entry_disp'));
		next if ($temp eq '');
		next if ($num == 0);
		my $body = sb::Content->output(sb::TemplateManager->new($temp),
			'mode'      => 'page',
			'time'      => $self->{'time'},
			'blog'      => $self->{'blog'},
			'user'      => $self->{'user'},
			'cat'       => $self->{'cat'},
			'sortedcat' => $self->{'sortedcat'},
			'entry'     => $self->{'entry'},
			'entry_num' => $self->{'entry_num'},
			'num'       => $num,
			'entryinfo' => $self->{'entryinfo'},
			'callback'  => $self->{'feedfuncs'},
		);
		if ($lang->charcode ne sb::App::Feed->get_code) { # convert character code
			$lang->checkcode('',$lang->charcode);
			$body = $lang->convert($body,sb::App::Feed->get_code);
		}
		eval {
			open(TOPOUT,">$file") or die(sb::Language->get->string('error_file_open') . $file);
			binmode(TOPOUT);
			print TOPOUT $body;
			close(TOPOUT);
			chmod(sb::Config->get->value('basic_file_attr'),$file);
		};
		last if ($@);
	}
	return ($@) ? $@ : undef;
}
sub set_entryinfo {
	my $self = shift;
	$self->{'entryinfo'} = sb::Content::_entry_info(
		'time' => $self->{'time'},
		'mode' => 'page',
		'conf' => sb::Config->get,
	);
}
sub set_latest_entries {
	my $self = shift;
	my $num  = shift;
	$num = sb::Config->get->value('conf_entry_disp') if (!$num);
	$self->{'entry'} = [
		sb::Data->load('Entry',
			'num'    => $num,
			'cond'   => {'stat'=>1},
			'sort'   => 'date',
			'order'  => 1,
			'detail' => 'on',
		)
	];
	$self->{'entry_num'} = sb::Data->matched;
}
sub set_callback_for_entry {
	my $self = shift;
	my %extend = (
		'main' => {
			'archives'         => sub { &_script_tag('archives_list',$_[0]); },
			'category'         => \&_category_list,
			'link'             => sub { &_script_tag('link_list',$_[0]); },
			'recent_comment'   => sub { &_script_tag('recent_comment_list',$_[0]); },
			'recent_trackback' => sub { &_script_tag('recent_trackback_list',$_[0]); },
			'latest_entry'     => sub { &_script_tag('latest_entry_list',$_[0]); },
			'profile'          => sub { &_script_tag('user_list',$_[0]); },
			'calendar'         => \&_calendar_for_entry,
		},
	);
	sb::Content::_register_callback(%extend);
	$self->{'ent_funcs'} = FUNCS_INITIALIZED;
	$self->{'feedfuncs'} = undef;
	$self->{'mainfuncs'} = undef;
}
sub set_callback_for_feed {
	my $self = shift;
	my %extend = (
		'main' => {
			'_main'          => \&sb::App::Feed::_common_parts,
			'feed_entrylist' => \&sb::App::Feed::_entrylist,
			'feed_entry'     => \&sb::App::Feed::_entry,
		},
	);
	sb::Content::_register_callback(%extend);
	$self->{'ent_funcs'} = undef;
	$self->{'feedfuncs'} = FUNCS_INITIALIZED;
	$self->{'mainfuncs'} = undef;
}
sub set_callback_for_main {
	my $self = shift;
	my %extend = ();
	sb::Content::_register_callback(%extend);
	$self->{'ent_funcs'} = undef;
	$self->{'feedfuncs'} = undef;
	$self->{'mainfuncs'} = FUNCS_INITIALIZED;
}
# ==================================================
# // private functions - utilities
# ==================================================
sub _initialize {
	my $self = shift;
	my @templates = sb::Data->load('Template','detail'=>'on');
	my %instances = (
		'css'  => undef,
		'html' => {},
	);
	foreach my $temp ( @templates ) {
		next if ($temp->main eq '' and $temp->entry eq '');
		if ($temp->use) {
			$self->{'def_temp'} = $temp->id;
			$instances{'css'} = sb::TemplateManager->new($temp->css) if ($temp->css ne '');
		}
		$instances{'html'}{$temp->id} = {'main'=>undef,'entry'=>undef};
		$instances{'html'}{$temp->id}{'main'}  = sb::TemplateManager->new($temp->main)  if ($temp->main ne '');
		$instances{'html'}{$temp->id}{'entry'} = sb::TemplateManager->new($temp->entry) if ($temp->entry ne '');
	}
	$self->{'template'} = \%instances;
	die(sb::Language->get->string('error_unknown')) if ($self->{'def_temp'} eq '');
	return($self);
}
sub _check_template {
	my $self = shift;
	my ($mode,$cat) = @_; # $mode = 'ent' or 'arc' or none
	my ($base,$css);
	my $conf = sb::Config->get;
	my $temp = undef;
	my $tid = ($mode eq 'arc') ? $conf->value('conf_archive_temp') : -1;
	$tid = $cat->temp if ($cat and $cat->temp ne '' and $cat->temp > -1);
	$tid = undef if ($tid == -1);
	$css = ( $tid ne '' and $conf->value('conf_css_change') ) # css path
	     ? $conf->value('conf_srv_cgi') . $conf->value('basic_sb') . '?css=' . $tid 
	     : $conf->value('conf_srv_base') . $conf->value('file_css');
	$temp = $self->{'template'}->{'html'}->{$tid} if ($tid ne '');
	$temp = $self->{'template'}->{'html'}->{$self->{'def_temp'}} if (!$temp);
	$base = ($mode eq 'ent' and $temp->{'entry'}) ? $temp->{'entry'} : $temp->{'main'}; # template base
	$base->clear;
	return($base,$css);
}
sub _generate_javascript {
	my $file = shift;
	my $body = shift;
	eval {
		open(JSOUT,">$file") or die(sb::Language->get->string('error_file_open') . $file);
		binmode(JSOUT);
		foreach my $line ( split("\n",$body) ) {
			$line =~ s/\'/&#39;/g;
			print JSOUT 'document.write(\'' . $line . '\\n\');',"\n";
		}
		close(JSOUT);
		chmod(sb::Config->get->value('basic_file_attr'),$file);
	};
	return ($@) ? $@ : undef;
}
# ==================================================
# // private functions - contents extensions
# ==================================================
sub _script_tag {
	my ($key,$cms) = @_;
	my $conf = sb::Config->get;
	my $check = $conf->value('conf_dir_base') . $conf->value('conf_dir_log') . $mListScripts{$key}->{'js'};
	if (-e $check and -s $check) {
		my $script = sprintf(SCRIPT_TAG,
			sb::Language->get->charset,
			$conf->value('conf_srv_base') . $conf->value('conf_dir_log') . $mListScripts{$key}->{'js'}
		);
		$cms->num(0);
		$cms->tag($key=>$script);
		return 1;
	} else {
		return 0;
	}
}
sub _calendar_for_entry {
	&_script_tag('calendar',$_[0]);
	&_script_tag('calendar2',$_[0]);
	&_script_tag('calendar_vertical',$_[0]);
	&_script_tag('calendar_horizontal',$_[0]);
	return 1;
}
sub _category_list {
	my $cms = shift;
	my %var = @_;
	my $check = &_script_tag('category_list',$cms);
	if ($check and $var{'entry'}->[0] and $var{'entry'}->[0]->cat ne '') {
		my $cat = $var{'cat'}->{$var{'entry'}->[0]->cat};
		if ($cat and $cat->sub ne '') {
			my $path = $var{'conf'}->value('conf_srv_base') . $var{'conf'}->value('conf_dir_log');
			$path .= SUBCATEGORY_PREFIX . $cat->id . '.js';
			$cms->num(0);
			$cms->tag('subcategory_list'=>sprintf(SCRIPT_TAG,$var{'lang'}->charset,$path));
		}
		return 1;
	}
	return $check;
}
sub _category_feeds {
	my $cms = shift;
	my %var = @_;
	sb::Content::_common_parts($cms,%var);
	my $path = $var{'conf'}->value('conf_srv_cgi') . $var{'conf'}->value('basic_feed');
	$cms->tag('site_rss' =>$path . 'rss&amp;cid=' . $var{'id'});
	$cms->tag('site_atom'=>$path . 'atom&amp;cid=' . $var{'id'});
}
1;
__END__
