# sb::App::Install - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::App::Install;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.07';
# 0.07 [2006/08/01] changed CHECK_URL
# 0.06 [2005/07/27] changed _convert_main to convert order of links/category/user correctly
# 0.05 [2005/07/26] changed _convert_main to convert recommendation order correctly
# 0.04 [2005/07/25] changed _convert_main to convert recommendation correctly
# 0.03 [2005/07/24] changed run to check whether xml request is acceptable or not
# 0.02 [2005/07/20] changed _check_environment to check file permissions as well
# 0.01 [2005/07/19] changed _convert_main to convert entry individually
# 0.00 [2005/07/11] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Interface ();
use sb::Config ();
use sb::Language ();
use sb::Data ();
use sb::TemplateManager ();
use sb::Driver;
use sb::App ();
@ISA = qw( sb::App );
# ==================================================
# // declaration for constant value
# ==================================================
sub FILES_AT_ONCE (){ 5 };
sub BACKUP        (){ 'backup/' };
sub OLD_ENTRY     (){ 'entry/' };
sub CONFIG        (){ 'configure' };
sub CATEGORY_NANE (){ '%Main%->%Sub%' };
sub TEMPLATE      (){ 'install.html' };
sub TEMP_INSTALL  (){ 'install.tmp' };
sub TEMP_UPGRADE  (){ 'upgrade.tmp' };
sub DUMMY_TEXT    (){ 'dummy.txt' };
sub CHECK_URL     (){ 'http://serennz.sakura.ne.jp/' };
sub DEFAULT_TITLE (){ 'My first weblog' };
sub DEFAULT_TEMP  (){ 'summer_breeze.cgi' };
# ==================================================
# // declaration for class member
# ==================================================
my %mOldData = ( # data structure for 'sb'
	'EntryDetail' => {
		'ent' => [
			'id',  'wid', 'subj','cat', 'date','auth','stat','com', 'tb',  'edit','acm', 
			'atb', 'form','ping','body','more','sum', 'add', 'key', 'file','ext', 'tmp', 
		],
		'com' => [
			'id',  'wid', 'eid', 'stat','date','auth','host',
			'mail','url', 'agnt','body','icon','ext', 
		],
		'tb'  => [
			'id','wid','eid','stat','date','subj','name','url','body','host',
		],
	},
	'struct' => {
		'Weblog' => [
			'id',    'plugin','pacc',  'psrv',  'psubj', 'pfrom', 'pcat',  'pthum', 'pform', 
			'pping', 'pcron', 'ptime', 'smtp',  'stype', 'ppass', 'papop', 'ext',   
		],
		'Entry' => [
			'id','wid','subj','cat','date','auth','stat','com','tb',
		],
		'Message' => [
			'id','wid','eid','stat','date','auth','host',
		],
		'Trackback' => [
			'id','wid','eid','stat','date','subj','name','url',
		],
		'Amazon' => [
			'id',  'wid', 'pid', 'mod', 'stat','name','cat', 'cre', 'date',
			'make','ism', 'imd', 'ilg', 'ava', 'lpr', 'opr', 'msg', 'url', 
		],
		'User' => [
			'id',    'wid',  'name',  'pass',  'real',  'prof',  'stat',  'mail',  'aws',   
			'edit',  'ext',  'info',  'notice','img',   'friend','disp',  'cat',   'form',  
		],
		'Link' => [
			'id','wid','name','url','text','user','order','disp','type',
		],
		'Category' => [
			'id','wid','name','text','tb','sub','order','temp','dir','disp','ext',
		],
		'Template' => [
			'id','wid','use','name','gen','mod','main','css','entry','info',
		],
		'Image' => [
			'id','wid','auth','date','name','file','thumb','stat','dir','eid',
		],
	},
	'file' => {
		'Entry'     => 'entry',
		'Message'   => 'message', 
		'Trackback' => 'trackback',
		'Link'      => 'link',
		'Amazon'    => 'amazon',
		'Category'  => 'category',
		'User'      => 'user',
		'Image'     => 'image',
		'Template'  => 'template',
		'Weblog'    => 'weblog',
	},
);
my %mLibraries = (
	'required' => ['LWP::UserAgent','HTTP::Request','Jcode',],
	'optional' => ['Image::Magick','Net::SMTP','Net::POP3',],
);
my @mObjects = (
	'amazon',    'category',  'entry',     'image',     'link',      'message',   
	'plugin',    'session',   'template',  'trackback', 'user',      'weblog',    
);
my @mHasDetail = ('entry','message','trackback','template','user');
# ==================================================
# // public functions
# ==================================================
# [note] -------------------------------------------
# Calling sb::App::Install, sb::Driver isn't loaded.
# So it's need to load sb::Driver on your own.
# ==================================================
sub run { # main routine
	my $class = shift;
	my $self = $class->SUPER::new(
		'conf' => sb::Config->get,
		'cgi'  => sb::Interface->get,
		'xml'  => undef,
		'sb'   => undef,
		'cms'  => undef,
		'step' => int(sb::Interface->get->value('step')),
		'err'  => undef,
		@_
	);
	if ($self->{'cgi'}->value('num') ne '' and !$self->_is_installing_as_new) {
		my $error = '';
		my $num   = int($self->{'cgi'}->value('num'));
		$self->{'sb'} = 1;
		$self->{'xml'} = 1;
		eval {
			$self->_load_driver; # need to load file driver
			$error = ($num >= 0) ? $self->_convert_main($num) : 1;
		};
		$error = 'error : ' . $@ if ($@);
		print $self->{'cgi'}->head('type'=>'text/xml','charset'=>'UTF-8');
		print '<?xml version="1.0"?>',"\n",'<result>',$error,'</result>',"\n";
	} else {
		eval {
			$self->{'cms'} = $self->_initialize;
			die("error_inst_load_temp\n") if (!$self->{'cms'});
			if ($self->{'step'} <= 0) {
				$self->_check_environment;
			} elsif ($self->{'sb'}) {
				$self->_step_to_upgrade;
			} else {
				$self->_step_to_install;
			}
		};
		if ($@) {
			print $self->error( $self->_parse_string($@) );
		} else {
			$self->_set_template_parts;
			print $self->{'cgi'}->head('type'=>'text/html') . $self->{'cms'}->output;
		}
	}
}
# ==================================================
# // private functions
# ==================================================
sub _initialize {
	my $self = shift;
	my $dir  = $self->{'conf'}->value('dir_data');
	umask(0); # set file mask
	if ($self->_is_installing_as_new) {
		$self->{'sb'} = undef;
		die("error_inst_init\n") if ($self->{'step'} == 0 and -e $dir . TEMP_INSTALL);
	} else {
		$self->{'sb'} = 1;
		die("error_inst_init\n") if ($self->{'step'} == 0 and -e $dir . TEMP_UPGRADE);
	}
	return sb::TemplateManager->new(
		$self->load_template(
			'file' => TEMPLATE,
			'dir'  => $self->{'conf'}->value('dir_temp') . sb::Language->get->code . '/',
		)
	);
}
sub _is_installing_as_new {
	my $self = shift;
	my $dir   = $self->{'conf'}->value('dir_data');
	my $cnt   = 0;
	my $dummy = DUMMY_TEXT;
	return( 1 ) if ( $self->_check_temporary(TEMP_INSTALL) );
	return( 0 ) if ( $self->_check_temporary(TEMP_UPGRADE) );
	opendir(CHECKDIR,$dir);
	my @files = readdir(CHECKDIR);
	closedir(CHECKDIR);
	foreach my $file (@files) {
		next if ($file =~ /^\./);
		next if ($file =~ /$dummy/i); # ignore dummy.txt
		$cnt++;
	}
	return ($cnt == 0);
}
sub _is_finished {
	my $self = shift;
	eval{
		sb::Driver->new($self->{'conf'}->value('conf_dbtype'));
		my $blog = sb::Data->load('Weblog','id'=>0);
		die("not_installed_yet\n") if (!$blog);
	};
	return ($@) ? undef : 1;
}
sub _set_template_parts {
	my $self = shift;
	my $cms  = $self->{'cms'};
	$self->common_template_parts($cms);
	$cms->num(0);
	$cms->tag('sb_install_cgi'=>$self->{'conf'}->value('basic_install'));
	$cms->tag('sb_step' . $self->{'step'} . '_on'=>'_on');
	$cms->block('sb_upgrade_menu'=>1) if ($self->{'sb'});
	$cms->block('sb_install_menu'=>1) if (!$self->{'sb'});
	$cms->block('sb_install_step' . $self->{'step'} => 1);
	$cms->tag('sb_site_cgi'=>$self->{'conf'}->value('conf_srv_cgi') . $self->{'conf'}->value('basic_admn'));
}
sub _parse_string {
	my $self = shift;
	my $text = shift;
	return('') if ($text eq '');
	chomp($text);
	return (sb::Language->get->string($text) ne '') ? sb::Language->get->string($text) : $text;
}
sub _check_environment {
	my $self = shift;
	my $lang = sb::Language->get;
	my $conf = $self->{'conf'};
	my $cms  = $self->{'cms'};
	my $flag = undef;
	# === checking external libralies ===
	foreach my $check ('required','optional') {
		my $cnt = 0;
		my @libs = @{$mLibraries{$check}};
		foreach my $lib (@libs) {
			next if ($lang->code ne 'ja' and $lib eq 'Jcode');
			my $text = '';
			eval("require $lib;");
			$text = ($@) ? $lang->string('parts_not_inst') : $lang->string('parts_install');
			$flag = 1 if ($@ and $check eq 'required');
			$cms->num($cnt);
			$cms->tag('sb_check_lib_status_' . $check=>sprintf($text,$lib));
			$cms->tag('sb_check_list_class'=>($cnt % 2) ? 'odd' : 'even');
			$cnt++;
		}
		$cms->block('check_lib_' . $check => $cnt);
	}
	# === checking outer access ===
	eval {
		die("error_inst_skipped\n") if ($flag);
		my $ua = LWP::UserAgent->new;
		$ua->parse_head(0);
		die($ua->request(HTTP::Request->new(GET => CHECK_URL))->status_line . "\n");
	};
	$cms->num(0);
	$cms->tag('sb_check_connect'=>$self->_parse_string($@));
	# === checking directory permissions ===
	my @dirs = ();
	push(@dirs,$conf->value('dir_data'));
	push(@dirs,$conf->value('dir_lock'));
	push(@dirs,$conf->value('conf_dir_base') . $conf->value('dir_style'));
	push(@dirs,$conf->value('conf_dir_base') . $conf->value('conf_dir_log'));
	push(@dirs,$conf->value('conf_dir_base') . $conf->value('conf_dir_img'));
	for (my $i=0;$i<@dirs;$i++) {
		$cms->num($i);
		my $text = $lang->string('parts_finefile');
		if (!-d $dirs[$i]) {
			$flag = 1;
			$text = $lang->string('parts_no_file');
		} elsif (!-r $dirs[$i]) {
			$flag = 1;
			$text = $lang->string('parts_unread');
		} elsif (!-w $dirs[$i]) {
			$flag = 1;
			$text = $lang->string('parts_unwrite');
		}
		$cms->tag('sb_check_dir_status'=>sprintf($text,$dirs[$i]));
		$cms->tag('sb_check_list_class'=>($i % 2) ? 'odd' : 'even');
	}
	$cms->block('check_dir'=>$#dirs + 1);
	# === checking file permission
	my @files = ();
	push(@files,$conf->value('conf_dir_base') . $conf->value('file_index'));
	push(@files,$conf->value('conf_dir_base') . $conf->value('file_css'));
	for (my $i=0;$i<@files;$i++) {
		$cms->num($i);
		my $text = $lang->string('parts_finefile');
		if (!-e $files[$i]) {
			$flag = 1;
			$text = $lang->string('parts_no_file');
		} elsif (!-r $files[$i]) {
			$flag = 1;
			$text = $lang->string('parts_unread');
		} elsif (!-w $files[$i]) {
			$flag = 1;
			$text = $lang->string('parts_unwrite');
		}
		$cms->tag('sb_check_file_status'=>sprintf($text,$files[$i]));
		$cms->tag('sb_check_list_class'=>($i % 2) ? 'odd' : 'even');
	}
	$cms->block('check_file'=>$#files + 1);
	# === finishing check ===
	if ($self->_is_finished) {
		$self->{'sb'} = undef;
		$cms->block('check_step0_done'=>1);
	} else {
		$cms->block('check_step0_next'=>1) if (!$flag);
		$cms->block('check_step0_error'=>1) if ($flag);
		$cms->block('check_upgrade_note'=>1) if ($self->{'sb'});
	}
}
sub _initialize_driver {
	my $self = shift;
	my $conf = $self->{'conf'};
	if ($conf->value('conf_dbtype') eq 'Text') {
		my $base = $conf->value('dbtxt_data');
		my $suf  = $conf->value('dbtxt_suf');
		my $idx  = $base . $conf->value('dbtxt_ids') . $suf;
		if (!-e $idx) {
			open(INDEX,">$idx");
			close(INDEX);
			chmod($conf->value('basic_file_attr'),$idx);
		}
		die("failed to create index file\n") if (!-e $idx);
		foreach my $name (@mObjects) {
			my $file = $base . $name . $suf;
			if (!-e $file) {
				open(DATA,">$file");
				close(DATA);
				chmod($conf->value('basic_file_attr'),$file);
			}
			die("failed to create data file for $name\n") if (!-e $file);
			if (grep(/^$name$/,@mHasDetail)) {
				my $dir = $base . $name;
				mkdir($dir,$conf->value('basic_dir_attr'))  if (!-e $dir);
				die("data dir for $name is not readable\n") if (!-r $dir);
				die("data dir for $name is not writable\n") if (!-w $dir);
			}
		}
		my $lock = $conf->value('dir_lock') . $conf->value('dbtxt_save');
		if (!-e $lock) {
			open(INDEX,">$lock");
			close(INDEX);
			chmod($conf->value('basic_file_attr'),$lock);
		}
		die("failed to create lock file for data base\n") if (!-e $lock);
	}
	# [TODO] other data base if need to be
}
sub _create_global_lock {
	my $self = shift;
	my $lock = $self->{'conf'}->value('dir_lock') . $self->{'conf'}->value('file_lock');
	if (!-e $lock) {
		open(INDEX,">$lock");
		close(INDEX);
		chmod($self->{'conf'}->value('basic_file_attr'),$lock);
	}
	die("fail to create lock file for global lock\n") if (!-e $lock);
}
sub _create_config_file {
	my $self = shift;
	my $file = $self->{'conf'}->value('dir_data') . $self->{'conf'}->value('file_conf');
	if (!-e $file) {
		open(CONFIG,">$file");
		close(CONFIG);
		chmod($self->{'conf'}->value('basic_file_attr'),$file);
	}
	die("failed to weblog config file\n") if (!-e $file);
}
sub _initialize_access_data {
	my $self = shift;
	my $file = $self->{'conf'}->value('dir_data') . $self->{'conf'}->value('file_access');
	my $dir  = $self->{'conf'}->value('dir_data') . $self->{'conf'}->value('dir_access');
	if (!-e $file) {
		open(INDEX,">$file");
		close(INDEX);
		chmod($self->{'conf'}->value('basic_file_attr'),$file);
	}
	die("failed to create data file for access log\n") if (!-e $file);
	mkdir($dir,$self->{'conf'}->value('basic_dir_attr')) if (!-e $dir);
	die("data dir for access log is not readable\n") if (!-r $dir);
	die("data dir for access log is not writable\n") if (!-w $dir);
	my $lock = $self->{'conf'}->value('dir_lock') . $self->{'conf'}->value('file_lckcnt');
	if (!-e $lock) {
		open(INDEX,">$lock");
		close(INDEX);
		chmod($self->{'conf'}->value('basic_file_attr'),$lock);
	}
	die("failed to create lock file for access log\n") if (!-e $lock);
}
sub _create_temporary {
	my $self = shift;
	my $file = shift;
	$file = $self->{'conf'}->value('dir_data') . $file;
	if (!-e $file) {
		open(INDEX,">$file");
		close(INDEX);
		chmod($self->{'conf'}->value('basic_file_attr'),$file);
	}
	die("failed to create temporary file\n") if (!-e $file);
}
sub _remove_temporary {
	my $self = shift;
	my $file = shift;
	$file = $self->{'conf'}->value('dir_data') . $file;
	unlink($file);
}
sub _check_temporary {
	my $self = shift;
	my $file = shift;
	$file = $self->{'conf'}->value('dir_data') . $file;
	return ( -e $file );
}
sub _load_driver {
	my $self = shift;
	sb::Driver->new($self->{'conf'}->value('conf_dbtype'));
}
# ==================================================
# // private functions - for installing
# ==================================================
sub _step_to_install {
	my $self = shift;
	my $cms  = $self->{'cms'};
	die("error_alredy_inst\n") if ($self->_is_finished);
	$self->_check_step_for_install;
	if ($self->{'step'} == 1) { # step 1 [ creating administrator ]
		$self->_create_temporary(TEMP_INSTALL);
		$cms->block('install_step1'=>1);
		$cms->block('step1_error'=>1) if ($self->{'err'} ne '');
	} elsif ($self->{'step'} == 2) { # step 2 [ server & directory settings ]
		$self->_create_config_file;
		$self->_initialize_driver;
		$self->_create_global_lock;
		$self->_load_driver; # need to load file driver
		my $admin = sb::Data->load('User','id'=>0);
		if (!$admin) {
			$admin = sb::Data->add('User',
				'name' => $self->{'cgi'}->value('__user'),
				'stat' => 0,
			);
			if ($admin) {
				$admin->pass($self->{'cgi'}->value('__pass'));
				sb::Data->update($admin);
			}
		}
		die("failed to create admin data\n") if (!$admin);
		$cms->num(0);
		if ($self->{'err'} eq '') {
			$cms->tag('srv_cgi' =>$self->_get_current_uri);
			$cms->tag('srv_base'=>$self->_get_current_uri);
			$cms->tag('dir_base'=>$self->{'conf'}->value('conf_dir_base'));
			$cms->tag('dir_log' =>$self->{'conf'}->value('conf_dir_log'));
			$cms->tag('dir_img' =>$self->{'conf'}->value('conf_dir_img'));
		} else {
			my $cgi = $self->{'cgi'};
			$cms->tag('srv_cgi' =>&sb::Config::_check_dir($cgi->value('srv_cgi')));
			$cms->tag('srv_base'=>&sb::Config::_check_dir($cgi->value('srv_base')));
			$cms->tag('dir_base'=>&sb::Config::_check_dir($cgi->value('dir_base')));
			$cms->tag('dir_log' =>&sb::Config::_check_dir($cgi->value('dir_log')));
			$cms->tag('dir_img' =>&sb::Config::_check_dir($cgi->value('dir_img')));
		}
		$cms->block('install_step2'=>1);
		$cms->block('step2_error'=>1) if ($self->{'err'} ne '');
	} elsif ($self->{'step'} == 3) { # step 3 [ weblog configuration ]
		$self->_load_driver; # need to load file driver
		my $conf = $self->{'conf'};
		my $cgi  = $self->{'cgi'};
		$conf->value('conf_srv_cgi' =>&sb::Config::_check_dir($cgi->value('srv_cgi')));
		$conf->value('conf_srv_base'=>&sb::Config::_check_dir($cgi->value('srv_base')));
		$conf->value('conf_dir_base'=>&sb::Config::_check_dir($cgi->value('dir_base')));
		$conf->value('conf_dir_log' =>&sb::Config::_check_dir($cgi->value('dir_log')));
		$conf->value('conf_dir_img' =>&sb::Config::_check_dir($cgi->value('dir_img')));
		$conf->store;
		$cms->tag('blog_title'=>DEFAULT_TITLE);
		$cms->block('install_step3'=>1);
	} else { # finishing ...
		$self->_load_driver; # need to load file driver
		my $cgi  = $self->{'cgi'};
		my $blog = sb::Data->load('Weblog','id'=>0);
		$blog = sb::Data->add('Weblog') if (!$blog);
		if ($blog) {
			$blog->title(sb::Text->entitize($cgi->value('blog_title')));
			$blog->text(sb::Text->entitize($cgi->value('blog_desc')));
			sb::Data->update($blog);
		}
		require sb::Admin::Template;
		my $temp = sb::Admin::Template->import_template(
			'cont' => $self->_load_template_package,
			'time' => $self->{'time'}
		);
		if ($temp) {
			$temp->use(1);
			sb::Data->update($temp);
		}
		$self->_initialize_access_data;
		$self->_remove_temporary(TEMP_INSTALL);
	}
}
sub _check_step_for_install {
	my $self = shift;
	die("error_installing\n") if ($self->{'step'} > 1 and !$self->_check_temporary(TEMP_INSTALL));
	if ($self->{'step'} == 2) {
		require sb::Admin::User;
		$self->{'err'} = sb::Admin::User->check_user(
			'pass'       => $self->{'cgi'}->value('__pass'),
			'conf'       => $self->{'cgi'}->value('__conf'),
			'check_name' => 0,
		);
		my $name = $self->{'cgi'}->value('__user');
		if ($name =~ /^[a-zA-Z0-9_\-\.]+$/) {
			if ($self->{'err'} ne '') {
				$self->{'cms'}->num(0);
				$self->{'cms'}->tag('install_user'=>$name);
			}
		} else {
			$self->{'err'} = "error_wrong_text\n";
		}
		$self->{'step'} = 1 if ($self->{'err'} ne '');
	} elsif ($self->{'step'} == 3) {
		my $cgi  = $self->{'cgi'};
		my $base = &sb::Config::_check_dir($cgi->value('dir_base'));
		my @dirs = ();
		push(@dirs,$base . &sb::Config::_check_dir($cgi->value('dir_log')));
		push(@dirs,$base . &sb::Config::_check_dir($cgi->value('dir_img')));
		foreach my $dir (@dirs) {
			$self->{'err'} = 'not_fine' if (!-d $dir or !-r $dir or !-w $dir);
		}
		$self->{'step'} = 2 if ($self->{'err'} ne '');
	}
}
sub _get_current_uri {
	my $self = shift;
	my $host = $ENV{'HTTP_HOST'} . $ENV{'SCRIPT_NAME'};
	$host =~ s/(.*[:\/\\])(.*)/$1/;
	return 'http://' . $host;
}
sub _load_template_package {
	my $self = shift;
	my $file = $self->{'conf'}->value('dir_temp') . DEFAULT_TEMP;
	open(TEMPIN,"<$file") or die("Fail to open : $file\n");
	binmode(TEMPIN);
	my @template = <TEMPIN>;
	close(TEMPIN);
	return join('',@template);
}
# ==================================================
# // private functions - for upgrading
# ==================================================
sub _step_to_upgrade {
	my $self = shift;
	my $cms  = $self->{'cms'};
	die("error_alredy_inst\n") if ($self->_is_finished);
	$self->_check_step_for_upgrade;
	if ($self->{'step'} == 1) { # step 1 [ login ]
		$self->_create_temporary(TEMP_UPGRADE);
		$cms->block('upgrade_step1'=>1);
		$cms->block('step1_error'=>1) if ($self->{'err'} ne '');
	} elsif ($self->{'step'} == 2) { # step 2 [ backup ]
		$self->_move_files;
		$self->_create_config_file;
		$self->_create_global_lock;
		$self->_initialize_driver_to_upgrade;
		$cms->block('upgrade_step2'=>1);
	} elsif ($self->{'step'} == 3) { # step 3 [ converting ]
		if ($self->{'cgi'}->value('check_xml') eq 'on') {
			my $check = $self->_get_entries;
			$cms->num(0);
			$cms->tag('total_process'=>$check);
			$cms->block('upgrade_step3_finish'=>1);
		} else {
			$self->_load_driver; # need to load file driver
			my $step  = $self->_progress_for_step3;
			my $check = $self->_get_entries;
			my $end   = int($check / FILES_AT_ONCE) + 1;
			my $percent = int(($step + 1)/($end + 1) * 100);
			$end-- if ($check > 0 and ($check % FILES_AT_ONCE) == 0);
			$self->_convert_main($step);
			$step++;
			$self->_progress_for_step3($step);
			$cms->num(0);
			$cms->tag('convert_progress'=>'<strong>' . $percent . ' %</strong>');
			$cms->block(($step == ($end + 1)) ? 'upgrade_step3_finish' : 'upgrade_step3_continue'=>1);
		}
		$cms->block('upgrade_step3'=>1);
	} else {
		$self->_load_driver; # need to load file driver
		require sb::Admin::Template;
		my $temp = sb::Admin::Template->import_template(
			'cont' => $self->_load_template_package,
			'time' => $self->{'time'}
		);
		sb::Data->update($temp) if ($temp);
		$self->_convert_configuration;
		$self->_initialize_access_data;
		$self->_remove_temporary(TEMP_UPGRADE);
	}
}
sub _progress_for_step3 {
	my $self = shift;
	my $update = shift;
	my $file = $self->{'conf'}->value('dir_data') . TEMP_UPGRADE;
	if ($update) {
		open(TEMP,">$file") or die("Fail to open : $file\n");
		binmode(TEMP);
		print TEMP $update,"\n";
		close(TEMP);
		return( undef );
	} else {
		open(TEMP,"<$file") or die("Fail to open : $file\n");
		my $cnt = <TEMP>;
		close(TEMP);
		return int($cnt);
	}
}
sub _convert_main {
	my $self = shift;
	my $step = shift;
	my $conf = $self->_load_old_config;
	if ($step == 0) { # === except entry, message, trackback and weblog ===
		foreach my $elem ( keys(%{$mOldData{'struct'}}) ) {
			next if ($elem eq 'Entry' or $elem eq 'Message' or $elem eq 'Trackback' or $elem eq 'Weblog');
			my $class = 'sb::Data::' . $elem;
			my $data = $self->_read_old_data($elem);
			my @ids = sort { $a <=> $b } keys(%{$data->{'data'}});
			my @added_categories = ();
			eval("require $class;");
			if ($elem eq 'Amazon') { # preparation for recommendation
				my @ordered = sort {
					$data->{'data'}->{$a}->{'mod'} <=> $data->{'data'}->{$b}->{'mod'}
				} keys(%{$data->{'data'}});
				my $num = 0;
				foreach my $id ( @ordered ) {
					$data->{'data'}->{$id}->{'order'} = $num++;
				}
			}
			foreach my $id ( @ids ) {
				my $old = $data->{'data'}->{$id};
				my $obj = $class->alloc();
				foreach my $val ( keys(%{$old}) ) {
					$obj->{$val} = $old->{$val};
				}
				if ($elem eq 'Category') { # checking sub-categories
					$obj->{'order'} = $data->{'num'} - $old->{'order'}; # opposite order in Serene Bach
					if ($obj->{'sub'} ne '') {
						my @children = split(':',$obj->{'sub'});
						$obj->{'sub'} = '';
						foreach my $name ( @children ) {
							my $child = sb::Data->add('Category',
								'main' => $id,
								'name' => $name,
								'url'  => '',
								'text' => '',
								'temp' => $obj->{'temp'},
								'dir'  => $obj->{'dir'},
								'disp' => $obj->{'disp'},
								'sub'  => '',
							);
							if ($child) {
								push(@added_categories,$child);
								$obj->{'sub'} .= $child->id . ',';
							}
						} # end of foreach my $name
					} # end of if ($obj->{'sub'} ne '')
				} elsif ($elem eq 'Image') { # checking status for images
					my @img_stat = split(':',$obj->{'stat'});
					$obj->{'stat'} = $img_stat[0];
					$obj->{'icon_c'} = $img_stat[1];
					$obj->{'icon_t'} = $img_stat[2];
					$obj->{'tz'} = $conf->{'timezone'};
				} elsif ($elem eq 'Link') { # checking disp setting for links
					$obj->{'disp'} = int($old->{'disp'}); # Empty is ingnored in Serene Bach, so should be set as 0
					$obj->{'order'} = $data->{'num'} - $old->{'order'}; # opposite order in Serene Bach
				} elsif ($elem eq 'Amazon') { # checking date/order for amazon
					$obj->{'cre'} =~ s/&sb;/\n/g;
					$obj->{'mod'} = undef; # this field removed
					$obj->{'date'} = $old->{'mod'};
					$obj->{'tz'} = $conf->{'timezone'};
					$obj->{'days'} = $old->{'date'};
				} elsif ($elem eq 'User') { # checking user settings
					my $new_set = '';
					my @edit_stat = split(':',$obj->{'edit'});
					for (my $i=0;$i<@edit_stat;$i++) {
						$new_set .= $edit_stat[$i] . ':';
						$new_set .= '0:' if ($i == 8); # imagemax option
					}
					$new_set .= '1:'; # related category option
					$new_set .= '1:'; # opening category field option
					$obj->{'edit'} = $new_set;
					$obj->{'order'} = $old->{'id'};
					$obj->{'ext'} = &sb::Data::User::DEFALT_TOOLICON();
				} # end of elsif ($elem eq 'User')
				sb::Data->update($obj);
			} # end of foreach my $id
			sb::Data->update(@added_categories) if (@added_categories);
		} # end of foreach my $elem
		return 1;
	} else { # === entry / message / trackback ===
		require sb::Data::Entry;
		require sb::Data::Message;
		require sb::Data::Trackback;
		my $max   = $self->{'xml'} ? 1 : FILES_AT_ONCE;
		my @files = sort { $a <=> $b } $self->_get_entries;
		my $table = $self->_check_category;
		my $check = @files;
		my $idx = $self->_read_old_data('Entry');
		my $bgn = ($step - 1) * $max;
		my $end = $bgn + $max;
		$end = $check if ($end > $check);
		for (my $i=$bgn;$i<$end;$i++) {
			my $data = $self->_read_old_details($files[$i]);
			my $entry = sb::Data::Entry->alloc();
			foreach my $val ( keys(%{$data->{'ent'}}) ) {
				$entry->{$val} = $data->{'ent'}->{$val};
			}
			$entry->{'add'} = '';
			my $cat = $idx->{'data'}->{$entry->{'id'}}->{'cat'};
			if ($cat ne '' and $table->{$cat} ne '') {
				$entry->{'cat'} = $table->{$cat};
				if (index($cat,'->') > -1) {
					my $main = (split('->',$cat,2))[0];
					$entry->{'add'} = ',' . $table->{$main} . ',' if ($table->{$main} ne '');
				}
			}
			$entry->{'tz'} = $conf->{'timezone'};
			sb::Data->update($entry);
			foreach my $label ('com','tb') {
				next if (ref($data->{$label}) ne 'ARRAY');
				next if (!@{$data->{$label}});
				foreach my $old ( @{$data->{$label}} ) {
					my $class = ($label eq 'com') ? 'sb::Data::Message' : 'sb::Data::Trackback';
					my $obj = $class->alloc();
					foreach my $val ( keys(%{$old}) ) {
						$obj->{$val} = $old->{$val};
					}
					$obj->{'tz'} = $conf->{'timezone'};
					sb::Data->update($obj);
				} # end of foreach my $old
			} # end foreacy my $label
		} # end of for ($i)
		return ($end < $check) ? 1 : 'completed';
	} # end of === entry / message / trackback ===
}
sub _check_category {
	my $self = shift;
	my %table = ();
	my %cats = sb::Data->load_as_hash('Category');
	foreach my $cat ( values(%cats) ) {
		my $name = $cat->fullname(\%cats,CATEGORY_NANE);
		$table{$name} = $cat->id;
	}
	return \%table;
}
sub _initialize_driver_to_upgrade {
	my $self = shift;
	$self->_initialize_driver;
	if ($self->{'conf'}->value('conf_dbtype') eq 'Text') {
		my %nums = ();
		foreach my $elem ( keys(%{$mOldData{'struct'}}) ) {
			my $data = $self->_read_old_data($elem,'number_only');
			$nums{lc($elem)} = $data->{'num'};
		}
		require sb::Driver::Text;
		&sb::Driver::Text::_save_id(%nums);
	}
	# [TODO] other data base if need to be
}
sub _check_step_for_upgrade {
	my $self = shift;
	my $cgi  = $self->{'cgi'};
	die("error_installing\n") if ($self->{'step'} > 1 and !$self->_check_temporary(TEMP_UPGRADE));
	if ($self->{'step'} == 2) {
		my $user = $self->_read_old_data('User');
		my $admn = $user->{'data'}->{0};
		$self->{'err'} = "wrong_user\n" if ($admn->{'name'} ne $cgi->value('__user'));
		$self->{'err'} = "wrong_pass\n" if (crypt($cgi->value('__pass'),$admn->{'pass'}) ne $admn->{'pass'});
		$self->{'step'} = 1 if ($self->{'err'} ne '');
	}
}
sub _get_entries {
	my $self = shift;
	my $dir = $self->{'conf'}->value('dir_data') . BACKUP . OLD_ENTRY;
	opendir(ENTRYDIR,$dir);
	my @files = grep !/^\./, readdir ENTRYDIR;
	closedir(ENTRYDIR);
	return(@files);
}
sub _move_files {
	my $self = shift;
	my $dir  = $self->{'conf'}->value('dir_data');
	my $back = $dir . BACKUP;
	mkdir($back,$self->{'conf'}->value('basic_dir_attr')) if (!-e $back);
	die("data dir for $back is not readable\n") if (!-r $back);
	die("data dir for $back is not writable\n") if (!-w $back);
	opendir(CHECKDIR,$dir);
	my @files = readdir(CHECKDIR);
	closedir(CHECKDIR);
	foreach my $file (@files) {
		my $check = $file . '/';
		next if ($file =~ /^\./);
		next if ($file eq TEMP_UPGRADE);
		next if ($check eq BACKUP);
		rename($dir . $file, $back . $file) or die("fail to move $file to backup\n");
	}
}
sub _load_old_config {
	my $self = shift;
	my %old  = ();
	my $file = $self->{'conf'}->value('dir_data') . BACKUP . CONFIG . $self->{'conf'}->value('file_suf');
	open(CONF,"<$file") or die("Fail to open : $file\n");
	while (my $line = <CONF>) {
		$line =~ tr/\x0D\x0A//d;
		my ($key,$val) = split("\t",$line,2);
		next if ($key eq '');
		$old{$key} = &_decode_old_data($val);
	}
	close(CONF);
	return \%old;
}
sub _convert_configuration {
	my $self = shift;
	my $conf = $self->{'conf'};
	my %old  = %{$self->_load_old_config()};
	foreach my $key ( $conf->get_keys ) {
		if ($key =~ /^conf_(.+)/) {
			my $old_key = $1;
			next if (!defined($old{$old_key}));
			$conf->value($key => $old{$1});
		}
	}
	my $date_format = $self->_convert_time_format($old{'disptime'});
	foreach my $key ( keys(%{$date_format}) ) {
		$conf->value($key => $date_format->{$key});
	}
	$conf->store;
	require sb::Data::Weblog;
	my $data = $self->_read_old_data('Weblog');
	my $blog = $data->{'data'}->{0};
	my $obj  = sb::Data::Weblog->alloc();
	foreach my $val ( keys(%{$blog}) ) {
		$obj->{$val} = $blog->{$val};
	}
	$obj->{'title'} = $old{'blog_title'};
	$obj->{'text'} = sb::Text->entitize($old{'blog_desc'});
	$obj->{'plugin'} = &sb::Data::Weblog::DEFAULT_PLUGIN();
	sb::Data->update($obj);
}
sub _read_old_data {
	my $self = shift;
	my $type = shift;
	my $flag = shift if ($@);
	my %data = ('num'=>0,'data'=>{});
	my $base = $mOldData{'file'}{$type} . $self->{'conf'}->value('file_suf');
	my $dir  = $self->{'conf'}->value('dir_data');
	my $file = (-e $dir . BACKUP . $base) ? $dir . BACKUP . $base : $dir . $base;
	open(DATAIN,"<$file") or die("Fail to open : $file\n");
	binmode(DATAIN);
	$data{'num'} = <DATAIN>;
	if (!$flag) {
		while (my $line = <DATAIN>) {
			$line =~ tr/\x0D\x0A//d;
			my ($num,$tmp) = split('<>',$line,2);
			$data{'data'}->{$num} = {};
			foreach my $elem ( @{$mOldData{'struct'}->{$type}} ) {
				($tmp,$line) = split('<>',$line,2);
				$data{'data'}->{$num}->{$elem} = &_decode_old_data($tmp);
			}
		}
	}
	close(DATAIN);
	$data{'num'} = int($data{'num'});
	return( \%data );
}
sub _read_old_details {
	my $self = shift;
	my $base = shift;
	my %data = ('ent'=>{},'com'=>[],'tb'=>[]);
	my %num  = ();
	my $dir  = $self->{'conf'}->value('dir_data');
	my $file = (-e $dir . BACKUP . OLD_ENTRY . $base) 
	         ? $dir . BACKUP . OLD_ENTRY . $base 
	         : $dir . OLD_ENTRY . $base;
	open(DATAIN,"<$file") or die("Fail to open : $file\n");
	binmode(DATAIN);
	while (my $line = <DATAIN>) {
		$line =~ tr/\x0D\x0A//d;
		my ($label,$tmp) = split("\t",$line,2);
		if ($label eq 'com' or $label eq 'tb') {
			$data{$label}[$num{$label}] = {};
		}
		my $val = '';
		foreach my $key ( @{$mOldData{'EntryDetail'}{$label}} ) {
			($val,$tmp) = split('<>',$tmp,2);
			if ($label eq 'com' or $label eq 'tb') {
				$data{$label}[$num{$label}]{$key} = &_decode_old_data($val);
			} else {
				$data{$label}{$key} = &_decode_old_data($val);
			}
		}
		$num{$label}++ if ($label eq 'com' or $label eq 'tb');
	}
	close(DATAIN);
	return( \%data );
}
sub _decode_old_data {
	my $text = shift;
	my @lines = split('%n',$text);
	$text = '';
	foreach my $line (@lines) {
		my $cnt = ($line =~ tr/%/%/);
		$line .= ($cnt % 2) ? '%n' : "\n";
		$text .= $line;
	}
	while ($text =~ /\n$/) {
		$text =~ s/\n$//g;
	}
	$text =~ s/%%/%/g;
	return(sb::Text->detitize($text));
}
sub _convert_time_format {
	my $self = shift;
	my $type = shift;
	if ($type eq 'LstYear') {
		return {
			'conf_entry_date'  => '%Year%/%Mon%/%Day% %Week%',
			'conf_entry_time'  => '%Hour%:%Min%',
			'conf_msg_time'    => '%Year%/%Mon%/%Day%  %Hour%:%Min%',
			'conf_dateinlist'  => ' (%Year%/%Mon%/%Day%)',
			'conf_archivelist' => '%MonLong% %Year%',
			'conf_time_lang'   => 'en',
		};
	} elsif ($type eq 'LstNone') {
		return {
			'conf_entry_date'  => '%Year%/%Mon%/%Day% %Week%',
			'conf_entry_time'  => '%Hour%:%Min%',
			'conf_msg_time'    => '%Year%/%Mon%/%Day%  %Hour%:%Min%',
			'conf_dateinlist'  => '',
			'conf_archivelist' => '%MonLong% %Year%',
			'conf_time_lang'   => 'en',
		};
	} elsif ($type eq 'EngLong') {
		return {
			'conf_entry_date'  => '%WeekLong% %DayOrd% %MonLong% %Year%',
			'conf_entry_time'  => '%Hour%:%Min%',
			'conf_msg_time'    => '%Week% %Day%/%Mon%/%Year% %Hour%:%Min%',
			'conf_dateinlist'  => ' (%Mon%/%Day%)',
			'conf_archivelist' => '%MonLong% %Year%',
			'conf_time_lang'   => 'en',
		};
	} elsif ($type eq 'EngShrt') {
		return {
			'conf_entry_date'  => '%Week% %Day% %MonShort% %Year%',
			'conf_entry_time'  => '%Hour%:%Min%',
			'conf_msg_time'    => '%Week% %Day%/%Mon%/%Year% %Hour%:%Min%',
			'conf_dateinlist'  => ' (%Mon%/%Day%)',
			'conf_archivelist' => '%MonLong% %Year%',
			'conf_time_lang'   => 'en',
		};
	} elsif ($type eq 'EngNum') {
		return {
			'conf_entry_date'  => '%Year%/%Mon%/%Day% %Week%',
			'conf_entry_time'  => '%Hour%:%Min%',
			'conf_msg_time'    => '%Year%/%Mon%/%Day%  %Hour%:%Min%',
			'conf_dateinlist'  => ' (%Mon%/%Day%)',
			'conf_archivelist' => '%MonLong% %Year%',
			'conf_time_lang'   => 'en',
		};
	} elsif ($type eq 'French') {
		return {
			'conf_entry_date'  => '%WeekLong% %Day% %MonLong% %Year%',
			'conf_entry_time'  => '%Hour%:%Min%',
			'conf_msg_time'    => '%Week% %Day%/%Mon%/%Year% %Hour%:%Min%',
			'conf_dateinlist'  => ' (%Mon%/%Day%)',
			'conf_archivelist' => '%MonLong% %Year%',
			'conf_time_lang'   => 'fr',
		};
	} elsif ($type eq 'JpnNum') {
		return {
			'conf_entry_date'  => '%Year%/%Mon%/%Day% %Week%',
			'conf_entry_time'  => '%Hour%:%Min%',
			'conf_msg_time'    => '%Year%/%Mon%/%Day%  %Hour%:%Min%',
			'conf_dateinlist'  => ' (%Mon%/%Day%)',
			'conf_archivelist' => '%Year%/%Mon%',
			'conf_time_lang'   => 'ja',
		};
	}
	return {
		'conf_entry_date'  => '%Year%.%Mon%.%Day% %WeekLong%',
		'conf_entry_time'  => '%Hour%:%Min%',
		'conf_msg_time'    => '%Year%/%Mon%/%Day% %Hour12%:%Min% %HourAP%',
		'conf_dateinlist'  => ' (%Mon%/%Day%)',
		'conf_archivelist' => '%MonLong% %Year%',
		'conf_time_lang'   => 'en',
	};
}
1;
__END__
