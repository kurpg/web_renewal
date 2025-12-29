# sb::Plugin - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Plugin;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.06';
# 0.06 [2006/11/07] changed _initialize to ignore debug code
# 0.05 [2006/10/11] changed register_plugin to set plugin param correctly
# 0.04 [2005/07/25] added 'receipt' to @pExtraTypes
# 0.03 [2005/07/24] chnaged register_content_module to allow multiple cms modules for a plugin
# 0.02 [2005/07/09] changed load_extra_module to handle extra plugins correctly
# 0.01 [2005/07/06] added register and loader for extra module to handle extra plugins.
# 0.00 [2005/02/01] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Config ();
use sb::Language ();
use sb::Data ();
# ==================================================
# // declaration for constant value
# ==================================================
sub DEFAULT_PLUGIN_DIR (){ './plugin/' };
sub TEMPLATE_DIR       (){ 'resource/' };
# ==================================================
# // declaration for class member
# ==================================================
my $mPluginDir  = undef;
my $mPluginSet  = undef;
my %mPlugins    = ();
my %mPluginData = (
	'cms'    => {},
	'admin'  => {},
	'format' => {},
	'extra'  => {},
);
# ==================================================
# // declaration for private variables
# ==================================================
my $pObject = undef;
my @pContentType = ('main','entry','comment','trackback','profile');
my @pExtraTypes  = ('counter','receipt'); # [memo] 'build' and 'update' will be added in the future.
# ==================================================
# // constructor
# ==================================================
sub get {
	my $class = shift;
	return($pObject) if ( defined($pObject) );
	my %param = (
		'dir' => DEFAULT_PLUGIN_DIR,
		'set' => 0,
		@_
	);
	my $weblog = sb::Data->load('Weblog','id'=>$param{'set'});
	$mPluginDir = $param{'dir'} if (-d $param{'dir'} and -r $param{'dir'});
	$mPluginSet = $weblog->plugin if ($weblog);
	$pObject = bless({},$class);
	return( $pObject->_initialize() );
}
sub new {
	&get; # 'new' is alias for 'get'
}
# ==================================================
# // destructor
# ==================================================
sub bye {
	my $class = shift;
	$pObject = undef;
}
sub DESTROY {
	my $self = shift;
	$mPluginDir  = undef;
	$mPluginSet  = undef;
	%mPlugins    = ();
	%mPluginData = ();
	return();
}
# ==================================================
# // public functions - registration
# ==================================================
sub register_plugin {
	my $self = shift;
	my %param = (
		'lang' => {},    # [optional][HASH] language settings
		'text' => {},    # [optional][HASH] plugin description
		'data' => undef, # [optional][SEL.] flag to use sb::Data::Plugin / 0:not use 1:use
		'file' => undef, # [optional][FILE] file name for plugin description
		@_
	);
	my ($name,$module) = &_check_caller(caller);
	$mPlugins{$name} = &_load_description(%param);
	$mPlugins{$name}->{'lang'} = $param{'lang'};
	if ($param{'data'}) {
		my $data = sb::Data->load('Plugin','cond'=>{'name'=>$name},'num'=>1);
		if (!$data) {
			$data = sb::Data->add('Plugin','name'=>$name);
			sb::Data->update($data) if ($data);
		}
		$mPlugins{$name}->{'data'} = ($data) ? $data : undef;
	}
	return 1;
}
sub register_admin_module {
	my $self = shift;
	my %param = (
		'mode'   => undef, # [required][CHAR] mode name
		'module' => undef, # [optional][CHAR] module name
		'level'  => 0,     # [optional][NUM.] authorization level / 0:everyone, 1:advanced user, 2:administrator
		@_
	);
	my ($name,$module) = &_check_caller(caller);
	return( undef ) if ($param{'mode'} eq '');
	return( undef ) if (&_ignore_plugin($name));
	$param{'module'} = $module if (!$param{'module'});
	$mPluginData{'admin'}->{$name} = \%param;
	sb::Language->get->string('mode_' . $param{'mode'} => $mPlugins{$name}->{'name'});
	return 1;
}
sub register_content_module {
	my $self = shift;
	my %param = (
		'type'     => undef, # [required][SEL.] indicated as @pContentType
		'callback' => undef, # [required][FUNC] reference of callback
		'field'    => undef, # [optional][CHAR] applied field if need be
		'name'     => undef, # [optional][CHAR] module name
		@_
	);
	my ($name,$module) = &_check_caller(caller);
	return( undef ) if (!$param{'type'});
	return( undef ) if (!grep($param{'type'},@pContentType));
	return( undef ) if (!$param{'callback'});
	return( undef ) if (&_ignore_plugin($name));
	$name = $param{'name'}  if ($param{'name'} ne '');
	$param{'field'} = $name if ($param{'field'} eq '');
	$mPluginData{'cms'}->{$name} = {
		'type'     => $param{'type'},
		'callback' => $param{'callback'},
		'field'    => $param{'field'},
	};
	return 1;
}
sub register_text_filter {
	my $self = shift;
	my %param = (
		'name'     => undef, # [required][CHAR] name of text format
		'callback' => undef, # [required][FUNC] reference of callback
		@_
	);
	my ($name,$module) = &_check_caller(caller);
	return( undef ) if (!$param{'name'});
	return( undef ) if ($param{'name'} =~ /\W/);
	return( undef ) if (!$param{'callback'});
	return( undef ) if (&_ignore_plugin($name));
	$mPluginData{'format'}->{$param{'name'}} = $param{'callback'};
	return 1;
}
sub register_extra_module {
	my $self = shift;
	my %param = (
		'type'     => undef, # [required][SEL.] indicated as @pExtraTypes
		'callback' => undef, # [required][FUNC] reference of callback
		@_
	);
	my ($name,$module) = &_check_caller(caller);
	return( undef ) if (!$param{'type'});
	return( undef ) if (!grep($param{'type'},@pExtraTypes));
	return( undef ) if (!$param{'callback'});
	return( undef ) if (&_ignore_plugin($name));
	if ( !defined($mPluginData{'extra'}->{$param{'type'}}) ) {
		$mPluginData{'extra'}->{$param{'type'}} = [ $param{'callback'} ];
	} else {
		push(@{$mPluginData{'extra'}->{$param{'type'}}},$param{'callback'});
	}
	return 1;
}
# ==================================================
# // public functions - loading plugins
# ==================================================
sub load_admin_module {
	my $self = shift;
	my %param = (
		'mode' => undef,
		'menu' => undef,
		@_
	);
	my @names = sort { $a cmp $b } keys(%{$mPluginData{'admin'}});
	foreach my $name ( @names ) {
		my $plugin = $mPluginData{'admin'}->{$name};
		$param{'mode'}->{$plugin->{'mode'}} = {
			'class' => $plugin->{'module'},
			'level' => $plugin->{'level'},
		};
		push(@{$param{'menu'}->{'util'}},$plugin->{'mode'});
	}
}
sub load_content_module {
	my $self = shift;
	my $list = shift;
	my @names = sort { $a cmp $b } keys(%{$mPluginData{'cms'}});
	foreach my $name ( @names ) {
		my $type = $mPluginData{'cms'}->{$name}->{'type'};
		my $area = $mPluginData{'cms'}->{$name}->{'field'};
		my $func = $mPluginData{'cms'}->{$name}->{'callback'};
		$list->{$type}{$area} = $func;
	}
}
sub load_text_filter {
	my $self = shift;
	my $name = shift;
	return( $mPluginData{'format'}->{$name} );
}
sub load_extra_module {
	my $self = shift;
	my $type = shift;
	return ( defined($mPluginData{'extra'}->{$type}) ) ? @{$mPluginData{'extra'}->{$type}} : ();
}
sub get_list {
	my $self = shift;
	return %mPlugins;
}
sub get_text_filter {
	my $self = shift;
	return keys(%{$mPluginData{'format'}});
}
# ==================================================
# // public functions - utilities
# ==================================================
sub load_template {
	my $self = shift;
	my %param = (
		'file' => undef,
		'dir'  => &_get_template_dir(),
		@_
	);
	return( undef ) if ($param{'file'} eq '');
	my $name = (&_check_caller(caller))[0];
	my $lang = sb::Language->get;
	my $file = $param{'dir'} . $param{'file'};
	my $text = undef;
	my @template = ();
	if ( -r $file ) {
		open(TEMPIN,"<$file") or die($lang->string('error_file_open') . $file);
		binmode(TEMPIN);
		@template = <TEMPIN>;
		close(TEMPIN);
	}
	$text = join('',@template);
	if ($mPlugins{$name}->{'lang'}->{$lang->code} ne $lang->charcode) {
		$lang->checkcode('',$mPlugins{$name}->{'lang'}->{$lang->code});
		$text = $lang->convert($text,$lang->charcode);
	}
	return($text);
}
sub get_resource_dir {
	my $self = shift;
	return( $mPluginDir . TEMPLATE_DIR );
}
sub get_data {
	my $self = shift;
	my $name = shift;
	$name = (&_check_caller(caller))[0] if ($name eq '');
	return( undef ) if (!$mPlugins{$name});
	return( $mPlugins{$name}->{'data'} );
}
sub set_data {
	my $self = shift;
	my %param = (
		'name' => undef,
		'data' => undef,
		@_
	);
	$param{'name'} = (&_check_caller(caller))[0] if ($param{'name'} eq '');
	return( undef ) if (!$mPlugins{$param{'name'}} or !defined($param{'data'}));
	$mPlugins{$param{'name'}}->{'data'} = $param{'data'};
	sb::Data->update($param{'data'});
	return( 1 );
}
# ==================================================
# // private functions
# ==================================================
sub _ignore_plugin {
	return ( index($mPluginSet,'[' . $_[0] . ']') == -1 );
}
sub _check_caller {
	my @calls = @_; # $calls[0]:package, $calls[1]:filename, $calls[2]:line
	return( &_extract_filename($calls[1]), $calls[0] );
}
sub _extract_filename {
	my $file = shift;
	$file =~ s/.*[:\/\\](.*)/$1/;
	$file =~ s/\[/&#91;/g;
	$file =~ s/\]/&#93;/g;
	return($file);
}
sub _get_template_dir {
	return( $mPluginDir . TEMPLATE_DIR . sb::Language->get->code . '/' );
}
sub _load_description {
	my %param = (@_);
	my $lang  = sb::Language->get;
	my $dir   = &_get_template_dir();
	if ($param{'file'} ne '' and $param{'lang'}->{$lang->code} ne '') {
		my $flag = ($param{'lang'}->{$lang->code} ne $lang->charcode);
		my $file = $dir . $param{'file'};
		$lang->checkcode('',$param{'lang'}->{$lang->code}) if ($flag);
		if (-r $file) {
			open(TEXTIN,"<$file");
			binmode(TEXTIN);
			while (my $line = <TEXTIN>) {
				next if ($line =~ /^#/);
				$line =~ s/\x0D\x0A|\x0D|\x0A//g;
				$line = $lang->convert($line,$lang->charcode) if ($flag);
				my ($field,$content) = split("\t",$line,2);
				if ($field eq 'resource') {
					my ($label,$string) = split("\t",$content,2);
					$lang->string($label=>$string);
				} else {
					$param{'text'}->{$field} = $content;
				}
			}
			close(TEXTIN);
		}
	}
	return($param{'text'});
}
sub _initialize {
	my $self = shift;
	if ($mPluginDir ne '' and -d $mPluginDir and -r $mPluginDir) {
		opendir(PLUGINDIR,$mPluginDir);
		my @filelist = readdir(PLUGINDIR);
		@filelist = sort { $a cmp $b } @filelist;
		foreach my $file (@filelist) {
			my $check = $mPluginDir . $file;
			next if (!-r $check or -d $check);
			next if ($file =~ /^\./);
			next if ($file =~ /^_/);
			next if ($file !~ /\.pl$/ and $file !~ /\.pm$/);
			eval{ require $check; };
			# die($@) if ($@); # [dbg]
		}
		closedir(PLUGINDIR);
	}
	return($self);
}
1;
__END__
