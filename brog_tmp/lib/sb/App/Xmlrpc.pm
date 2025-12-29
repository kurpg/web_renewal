# sb::App::Xmlrpc - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::App::Xmlrpc;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.03';
# 0.03 [2005/08/06] chnaged _edit_entry to check whether body is empty or not
# 0.02 [2005/07/16] changed _buikd_files to change the order of building files
# 0.01 [2005/07/08] changed _edit_entry to update "ping" correctly
# 0.00 [2004/02/01] generated
# [references] ====================================================================
# XML-RPC specification (in Japanese)
# http://lowlife.jp/yasusii/stories/9.html
# XML-RPC API for Movable Type (in Japanese)
# http://www.na.rim.or.jp/~tsupo/program/blogTool/mt_xmlRpc.html
# ===============================================================================
# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Interface ();
use sb::Language ();
use sb::Config ();
use sb::Plugin ();
use sb::Build ();
use sb::Ping ();
use sb::Lock ();
use sb::Time ();
use sb::Data ();
use sb::Admin::Entry ();
use sb::App ();
@ISA = qw( sb::App );
# ==================================================
# // declaration for constant value
# ==================================================
sub TIME_FORMAT     (){ '%Year%%Mon%%Day%T%Hour%:%Min%:%Sec%' };
sub TEXT_FORMAT_1   (){ 'Auto line breaking' };
sub OUTPUT_CHARSET  (){ 'UTF-8' };
sub OUTPUT_CHARCODE (){ 'utf8' };
# ==================================================
# // declaration for class member
# ==================================================
my %mMethodCallback = (
	'blogger.newPost'           => \&_blogger_newpost,
	'blogger.editPost'          => \&_blogger_editpost,
	'blogger.getRecentPosts'    => \&_blogger_getrecentposts,
	'blogger.getUsersBlogs'     => \&_blogger_getusersblogs,
	'blogger.getUserInfo'       => \&_blogger_getuserinfo,
	'blogger.deletePost'        => \&_blogger_deletepost,
	'metaWeblog.getPost'        => \&_metaweblog_getpost,
	'metaWeblog.newPost'        => \&_metaweblog_newpost,
	'metaWeblog.editPost'       => \&_metaweblog_editpost,
	'metaWeblog.getRecentPosts' => \&_metaweblog_getrecentposts,
	'metaWeblog.newMediaObject' => \&_metaweblog_newmediaobject,
	'mt.getCategoryList'        => \&_mt_getcategorylist,
	'mt.setPostCategories'      => \&_mt_setpostcategories,
	'mt.getPostCategories'      => \&_mt_getpostcategories,
	'mt.getRecentPostTitles'    => \&_mt_recentposttitles,
	'mt.publishPost'            => \&_mt_publishpost,
	'mt.supportedMethods'       => \&_mt_supportedmethods,
	'mt.supportedTextFilters'   => \&_mt_supportedtextfilters,
	'sb.getMediaObjectList'     => \&_getmediaobjectlist,
	'sb.getMediaObject'         => \&_getmediaobject,
	'sb.deleteMediaObject'      => \&_deletemediaobject,
);
my %mErrorCode = (
	1  => 'Unknown method. [%s]',
	2  => 'Too many parameters.',
	3  => 'Failed to authorize.',
	4  => 'The object does not exist.',
	5  => 'Failed to lock a file.',
	6  => 'Failed to upload a file.',
	7  => 'Permission denied.',
	8  => 'Lack of parameters.',
	99 => 'Unknown error. %s',
);
my @mScriptsForEntries = (
	'latest_entry_list','category_list','archives_list','calendar','calendar2','calendar_vertical','calendar_horizontal',
);
# ==================================================
# // destructor
# ==================================================
sub bye {
	my $self = shift;
	$self->{'lock'}->unlock if ($self->{'lock'});
	$self = undef;
	exit(0);
}
# ==================================================
# // public functions
# ==================================================
sub run {
	my $class = shift;
	my $cgi  = sb::Interface->get;
	my $self = $class->SUPER::new(
		'charset' => $cgi->value('charset'),
		'users'   => { sb::Data->load_as_hash('User') },
		@_
	);
	$self->{'charset'} = OUTPUT_CHARSET if ($self->{'charset'} eq '');
	my @stack = ($cgi->value('params') =~ /<param>(.*?)<\/param>/sg);
	my $method = $cgi->value('methodName');
	if ( $mMethodCallback{$method} ) {
		eval{ &{$mMethodCallback{$method}}($self,@stack) };
		$self->_response(99,sb::Text->entitize($@)) if ($@);
	} else {
		$self->_response(1,$method);
	}
}
# ==================================================
# // private functions - response
# ==================================================
sub _response {
	my $self = shift;
	my ($error,$input) = @_;
	my $output = '';
	my $bgn = ($error) ? 'fault><value><struct' : 'params><param><value';
	my $end = ($error) ? 'struct></value></fault' : 'value></param></params';
	$output .= '<?xml version="1.0" encoding="UTF-8"?>' . "\n";
	$output .= '<methodResponse><' . $bgn . '>' . "\n";
	if ($error) {
		$input = ($input ne '') ? sprintf($mErrorCode{$error},$input) : $mErrorCode{$error};
		$output .= '<member><name>faultCode</name><value><int>' . $error . '</int></value></member>' . "\n";
		$output .= '<member><name>faultString</name><value><string>' . $input . '</string></value></member>' . "\n";
	} else {
		$output .= $input . "\n";
	}
	$output .= '</' . $end . '></methodResponse>' . "\n";
	my $len = length($output);
	print sb::Interface->get->head(
		'type'    => 'text/xml',
		'charset' => 'UTF-8',
		'length'  => $len,
	);
	print $output;
	$self->bye;
}
# ==================================================
# // private functions - implementation for methods
# ==================================================
sub _blogger_newpost {
	my $self = shift;
	my $app  = shift; # string (not use)
	my $wid  = shift; # string (not use)
	my $user = &_value(shift); # string
	my $pass = &_value(shift); # string
	my $body = &_value(shift); # string
	my $flag = &_value(shift); # boolean
	$self->_response(2,undef) if (@_);
	$self->_response(3,undef) if ($self->check_password('user'=>$user,'pass'=>$pass));
	$self->_response(5,undef) if (!$self->_set_lock);
	my $entry = $self->_edit_entry(
		'entry'   => undef,
		'content' => {'description' => $body},
		'open'    => $flag,
	);
	$self->_response(0,($entry) ? '<string>' . $entry->id . '</string>' : '<boolean>0</boolean>');
}
sub _blogger_editpost {
	my $self = shift;
	my $app  = shift;  # string (not use)
	my $eid  = &_value(shift); # string
	my $user = &_value(shift); # string
	my $pass = &_value(shift); # string
	my $body = &_value(shift); # string
	my $flag = &_value(shift); # boolean
	$self->_response(2,undef) if (@_);
	$self->_response(3,undef) if ($self->check_password('user'=>$user,'pass'=>$pass));
	$self->_response(5,undef) if (!$self->_set_lock);
	my $entry = sb::Data->load('Entry','id'=>$eid);
	$self->_response(4,undef) if (!$entry);
	$self->_response(7,undef) if (!$self->check_permission('user'=>$entry->auth));
	$entry = $self->_edit_entry(
		'entry'   => $entry,
		'content' => {'description' => $body},
		'open'    => $flag,
	);
	$self->_response(0,($entry) ? '<boolean>1</boolean>' : '<boolean>0</boolean>');
}
sub _blogger_getrecentposts {
	my $self = shift;
	my $app  = shift; # string (not use)
	my $wid  = shift; # string (not use)
	my $user = &_value(shift); # string
	my $pass = &_value(shift); # string
	my $num  = &_value(shift); # int
	$self->_response(2,undef) if (@_);
	$self->_response(3,undef) if ($self->check_password('user'=>$user,'pass'=>$pass));
	my @entries = sb::Data->load('Entry',
		'bgn'    => 0,
		'num'    => $num,
		'sort'   => 'date',
		'order'  => 1,
		'detail' => 'on',
	);
	$self->_init_instance;
	my $out = '<array><data>' . "\n";
	foreach my $entry (@entries) {
		$out .= '<value>' . $self->_entry_struct('entry'=>$entry,'mode'=>'simple') . '</value>';
	}
	$out .= '</data></array>';
	$self->_response(0,$out);
}
sub _blogger_getusersblogs {
	my $self = shift;
	my $app  = shift; # string (not use)
	my $user = &_value(shift); # string
	my $pass = &_value(shift); # string
	$self->_response(2,undef) if (@_);
	$self->_response(3,undef) if ($self->check_password('user'=>$user,'pass'=>$pass));
	my $blog = sb::Data->load('Weblog','id'=>0)->title;
	my $url  = sb::Config->get->value('conf_srv_base');
	my $lang = sb::Language->get;
	$lang->checkcode('',$lang->charcode); # set default charcode
	$blog = $lang->convert($blog,OUTPUT_CHARCODE) if ($lang->charcode ne OUTPUT_CHARCODE);
	my @out = ('<array><data><value><struct>');
	push(@out,'<member><name>url</name><value><string>' . $url . '</string></value></member>');
	push(@out,'<member><name>blogid</name><value><string>0</string></value></member>');
	push(@out,'<member><name>blogName</name><value><string>' . $blog . '</string></value></member>');
	push(@out,'</struct></value></data></array>');
	$self->_response(0,join("\n",@out));
}
sub _blogger_getuserinfo {
	my $self = shift;
	my $app  = shift; # string (not use)
	my $user = &_value(shift); # string
	my $pass = &_value(shift); # string
	$self->_response(2,undef) if (@_);
	$self->_response(3,undef) if ($self->check_password('user'=>$user,'pass'=>$pass));
	$user = $self->{'user'};
	my $url  = sb::Config->get->value('conf_srv_base');
	my $name = $user->real;
	my $lang = sb::Language->get;
	$lang->checkcode('',$lang->charcode); # set default charcode
	$name = $lang->convert($name,OUTPUT_CHARCODE) if ($lang->charcode ne OUTPUT_CHARCODE);
	my @out = ('<struct>');
	push(@out,'<member><name>userid</name><value><string>' . $user->id . '</string></value></member>');
	push(@out,'<member><name>firstname</name><value><string>' . (split(/\s+/,$name,2))[0] . '</string></value></member>');
	push(@out,'<member><name>lastname</name><value><string>' . (split(/\s+/,$name,2))[1] . '</string></value></member>');
	push(@out,'<member><name>nickname</name><value><string>' . $name . '</string></value></member>');
	push(@out,'<member><name>email</name><value><string>' . $user->mail . '</string></value></member>');
	push(@out,'<member><name>url</name><value><string>' . $url . '</string></value></member>');
	push(@out,'</struct>');
	$self->_response(0,join("\n",@out));
}
sub _blogger_deletepost {
	my $self = shift;
	my $app  = shift; # string (not use)
	my $eid  = &_value(shift); # string
	my $user = &_value(shift); # string
	my $pass = &_value(shift); # string
	my $flag = shift; # boolean (not use)
	$self->_response(2,undef) if (@_);
	$self->_response(3,undef) if ($self->check_password('user'=>$user,'pass'=>$pass));
	$self->_response(5,undef) if (!$self->_set_lock);
	my $entry = sb::Data->load('Entry','id'=>$eid);
	$self->_response(4,undef) if (!$entry);
	$self->_response(7,undef) if (!$self->check_permission('user'=>$entry->auth));
	$entry->erase;
	sb::Data->update($entry);
	$self->_response(0,'<boolean>1</boolean>');
}
sub _metaweblog_getpost {
	my $self = shift;
	my $eid  = &_value(shift); # string
	my $user = &_value(shift); # string
	my $pass = &_value(shift); # string
	$self->_response(2,undef) if (@_);
	$self->_response(3,undef) if ($self->check_password('user'=>$user,'pass'=>$pass));
	my $entry = sb::Data->load('Entry','id'=>$eid);
	$self->_response(4,undef) if (!$entry);
	$self->_init_instance;
	$self->_response(0,$self->_entry_struct('entry'=>$entry,'mode'=>'detail'));
}
sub _metaweblog_newpost {
	my $self = shift;
	my $wid  = shift; # string (not use)
	my $user = &_value(shift); # string
	my $pass = &_value(shift); # string
	my $cont = &_value(shift); # struct
	my $flag = &_value(shift); # boolean
	$self->_response(2,undef) if (@_);
	$self->_response(3,undef) if ($self->check_password('user'=>$user,'pass'=>$pass));
	$self->_response(5,undef) if (!$self->_set_lock);
	my $entry = $self->_edit_entry(
		'entry'   => undef,
		'content' => $cont,
		'open'    => $flag,
	);
	$self->_response(0,($entry) ? '<string>' . $entry->id . '</string>' : '<boolean>0</boolean>');
}
sub _metaweblog_editpost {
	my $self = shift;
	my $eid  = &_value(shift); # string
	my $user = &_value(shift); # string
	my $pass = &_value(shift); # string
	my $cont = &_value(shift); # struct
	my $flag = &_value(shift); # boolean
	$self->_response(2,undef) if (@_);
	$self->_response(3,undef) if ($self->check_password('user'=>$user,'pass'=>$pass));
	$self->_response(5,undef) if (!$self->_set_lock);
	my $entry = sb::Data->load('Entry','id'=>$eid);
	$self->_response(4,undef) if (!$entry);
	$self->_response(7,undef) if (!$self->check_permission('user'=>$entry->auth));
	$entry = $self->_edit_entry(
		'entry'   => $entry,
		'content' => $cont,
		'open'    => $flag,
	);
	$self->_response(0,($entry) ? '<boolean>1</boolean>' : '<boolean>0</boolean>');
}
sub _metaweblog_getrecentposts {
	my $self = shift;
	my $wid  = shift; # string (not use)
	my $user = &_value(shift); # string
	my $pass = &_value(shift); # string
	my $num  = &_value(shift); # int
	$self->_response(2,undef) if (@_);
	$self->_response(3,undef) if ($self->check_password('user'=>$user,'pass'=>$pass));
	my @entries = sb::Data->load('Entry',
		'bgn'    => 0,
		'num'    => $num,
		'sort'   => 'date',
		'order'  => 1,
		'detail' => 'on',
	);
	$self->_init_instance;
	my $out = '<array><data>' . "\n";
	foreach my $entry (@entries) {
		$out .= '<value>' . $self->_entry_struct('entry'=>$entry,'mode'=>'detail') . '</value>';
	}
	$out .= '</data></array>';
	$self->_response(0,$out);
}
sub _metaweblog_newmediaobject {
	my $self = shift;
	my $wid  = shift; # string (not use)
	my $user = &_value(shift); # string
	my $pass = &_value(shift); # string
	my $file = &_value(shift); # struct
	$self->_response(2,undef) if (@_);
	$self->_response(3,undef) if ($self->check_password('user'=>$user,'pass'=>$pass));
	$self->_response(5,undef) if (!$self->_set_lock);
	$self->_response(8,undef) if (!$file or $file->{'name'} eq '');
	my $conf  = sb::Config->get;
	my $lang  = sb::Language->get;
	my $name  = $file->{'name'};
	my $field = 'upload_file:';
	$lang->checkcode('',$lang->code_for_charset($self->{'charset'})); # set input charcode
	$name = $lang->convert($name,$lang->charcode) if ($lang->charset ne $self->{'charset'});
	$field .= ' Content-Type:' . $file->{'type'}  . ';' if ($file->{'type'} ne '');
	$field .= ' filename=' . $name;
	my $img = sb::Data->add('Image','auth'=>$self->{'user'}->id);
	my @out = ();
	if ($img) {
		my $check = $img->upload(
			'entity' => $file->{'bits'},
			'label'  => 'upload_file',
			'thumb'  => ($conf->value('conf_thumbcheck')) ? 'on' : '',
			'header' => [ $field ],
			'name'   => $name,
			'fixed'  => $conf->value('conf_imagename'),
			'over'   => 1,
		);
		if ( $check ) {
			$img->date($self->{'time'});
			$img->tz($conf->value('conf_timezone'));
			sb::Data->update($img);
			push(@out,'<struct>');
			push(@out,'<member><name>url</name><value><string>' . $img->get_url . '</string></value></member>');
			push(@out,'</struct>');
		}
	}
	if (@out) {
		$self->_response(0,join("\n",@out));
	} else {
		$self->_response(6,undef);
	}
}
sub _mt_getcategorylist {
	my $self = shift;
	my $wid  = shift; # string (not use)
	my $user = &_value(shift); # string
	my $pass = &_value(shift); # string
	$self->_response(2,undef) if (@_);
	$self->_response(3,undef) if ($self->check_password('user'=>$user,'pass'=>$pass));
	$self->_init_instance;
	my $lang = sb::Language->get;
	my $list = $self->_sort_categories('cat'=>[ sort { $b->order <=> $a->order } values(%{$self->{'cat'}}) ]);
	my @out = ('<array><data>');
	$lang->checkcode('',$lang->charcode); # set default charcode
	foreach my $id ( split(',',$list) ) {
		next if ($id eq '');
		my $cat = $self->{'cat'}->{$id};
		my $name = $cat->fullname($self->{'cat'});
		$name = $lang->convert($name,OUTPUT_CHARCODE) if ($lang->charcode ne OUTPUT_CHARCODE);
		push(@out,'<value><struct>');
		push(@out,'<member><name>categoryId</name><value><string>' . $cat->id . '</string></value></member>');
		push(@out,'<member><name>categoryName</name><value><string>' . $name . '</string></value></member>');
		push(@out,'</struct></value>');
	}
	push(@out,'</data></array>');
	$self->_response(0,join("\n",@out));
}
sub _mt_setpostcategories {
	my $self = shift;
	my $eid  = &_value(shift); # string
	my $user = &_value(shift); # string
	my $pass = &_value(shift); # string
	my $cats = &_value(shift); # array [ struct ]
	$self->_response(2,undef) if (@_);
	$self->_response(3,undef) if ($self->check_password('user'=>$user,'pass'=>$pass));
	$self->_response(5,undef) if (!$self->_set_lock);
	$self->_response(8,undef) if (!$cats);
	my $entry = sb::Data->load('Entry','id'=>$eid);
	$self->_response(4,undef) if (!$entry);
	$self->_response(7,undef) if (!$self->check_permission('user'=>$entry->auth));
	$self->_init_instance;
	my $primary = '';
	my @related = ();
	foreach my $cat (@{$cats}) {
		my $id = int($cat->{'categoryId'});
		next if (!$self->{'cat'}->{$id});
		if ($cat->{'isPrimary'} and $primary eq '') {
			$primary = $id;
		} else {
			push(@related,$id);
		}
	}
	$entry->cat($primary);
	$entry->add(',' . join(',',@related) . ',') if (@related);
	$entry->edit($self->{'user'}->id);
	sb::Data->update($entry);
	$self->_response(0,'<boolean>1</boolean>');
}
sub _mt_getpostcategories {
	my $self = shift;
	my $eid  = &_value(shift); # string
	my $user = &_value(shift); # string
	my $pass = &_value(shift); # string
	$self->_response(2,undef) if (@_);
	$self->_response(3,undef) if ($self->check_password('user'=>$user,'pass'=>$pass));
	my $lang = sb::Language->get;
	my $entry = sb::Data->load('Entry','id'=>$eid);
	$self->_response(4,undef) if (!$entry);
	$self->_response(7,undef) if (!$self->check_permission('user'=>$entry->auth));
	$self->_init_instance;
	$lang->checkcode('',$lang->charcode); # set default charcode
	my @out  = ('<array><data>');
	my @cats = ($entry->cat);
	push(@cats,split(',',$entry->add)) if ($entry->add ne '');
	foreach my $id (@cats) {
		next if ($id eq '');
		my $cat = $self->{'cat'}->{$id};
		if ($cat) {
			my $name = $cat->fullname($self->{'cat'});
			$name = $lang->convert($name,OUTPUT_CHARCODE) if ($lang->charcode ne OUTPUT_CHARCODE);
			push(@out,'<value><struct>');
			push(@out,'<member><name>categoryId</name><value><string>' . $cat->id . '</string></value></member>');
			push(@out,'<member><name>categoryName</name><value><string>' . $name . '</string></value></member>');
			if ($entry->cat ne '' and $cat->id eq $entry->cat) {
				push(@out,'<member><name>isPrimary</name><value><boolean>1</boolean></value></member>');
			}
			push(@out,'</struct></value>');
		}
	}
	push(@out,'</data></array>');
	$self->_response(0,join("\n",@out));
}
sub _mt_recentposttitles {
	my $self = shift;
	my $wid  = shift; # string (not use)
	my $user = &_value(shift); # string
	my $pass = &_value(shift); # string
	my $num  = &_value(shift); # int
	$self->_response(2,undef) if (@_);
	$self->_response(3,undef) if ($self->check_password('user'=>$user,'pass'=>$pass));
	my @entries = sb::Data->load('Entry',
		'bgn'    => 0,
		'num'    => $num,
		'sort'   => 'date',
		'order'  => 1,
	);
	my $out = '<array><data>' . "\n";
	foreach my $entry (@entries) {
		$out .= '<value>' . $self->_entry_struct('entry'=>$entry,'mode'=>'basic') . '</value>';
	}
	$out .= '</data></array>';
	$self->_response(0,$out);
}
sub _mt_publishpost {
	my $self = shift;
	my $eid  = &_value(shift); # string
	my $user = &_value(shift); # string
	my $pass = &_value(shift); # string
	$self->_response(2,undef) if (@_);
	$self->_response(3,undef) if ($self->check_password('user'=>$user,'pass'=>$pass));
	$self->_response(5,undef) if (!$self->_set_lock);
	my $entry = sb::Data->load('Entry','id'=>$eid);
	$self->_response(4,undef) if (!$entry);
	$self->_response(7,undef) if (!$self->check_permission('user'=>$entry->auth));
	$self->_init_instance;
	$self->_build_files($entry);
	$self->_response(0,'<boolean>1</boolean>');
}
sub _mt_supportedmethods {
	my $self = shift;
	$self->_response(2,undef) if (@_);
	my $out = '<array><data>' . "\n";
	foreach my $method ( keys(%mMethodCallback) ) {
		next if ($method eq 'mt.supportedMethods');
		$out .= '<value><string>' . $method . '</string></value>' . "\n";
	}
	$out .= '</data></array>';
	$self->_response(0,$out);
}
sub _mt_supportedtextfilters {
	my $self = shift;
	$self->_response(2,undef) if (@_);
	my $out = '<array><data>';
	my @filters = sb::Plugin->get_text_filter;
	unshift(@filters,TEXT_FORMAT_1);
	foreach my $name (@filters) {
		my $key = ($name eq TEXT_FORMAT_1) ? 1 : $name;
		$out .= '<value><struct><member>' . "\n";
		$out .= '<name>label</name><value><string>' . $name . '</string></value>' . "\n";
		$out .= '</member><member>' . "\n";
		$out .= '<name>key</name><value><string>' . $key . '</string></value>' . "\n";
		$out .= '</member></struct></value>' . "\n";
	}
	$out .= '</data></array>';
	$self->_response(0,$out);
}
sub _getmediaobjectlist {
	my $self = shift;
	my $wid  = shift; # string (not use)
	my $user = &_value(shift); # string
	my $pass = &_value(shift); # string
	my $num  = &_value(shift); # int
	$self->_response(2,undef) if (@_);
	$self->_response(3,undef) if ($self->check_password('user'=>$user,'pass'=>$pass));
	my $lang = sb::Language->get;
	my @images = sb::Data->load('Image','bgn'=>0,'num'=>$num);
	my @out = ('<array><data>');
	$lang->checkcode('',$lang->charcode); # set default charcode
	foreach my $img (@images) {
		my $date = sb::Time->format('time'=>$img->date,'form'=>TIME_FORMAT);
		my $name = $img->name;
		$name = $lang->convert($name,OUTPUT_CHARCODE) if ($lang->charcode ne OUTPUT_CHARCODE);
		push(@out,'<value><struct>');
		push(@out,'<member><name>objectid</name><value><string>' . $img->id . '</string></value></member>');
		push(@out,'<member><name>dateCreated</name><value><dateTime.iso8601>' . $date . '</dateTime.iso8601></value></member>');
		push(@out,'<member><name>name</name><value><string>' . $name . '</string></value></member>');
		push(@out,'<member><name>url</name><value><string>' . $img->get_url . '</string></value></member>');
		push(@out,'<member><name>type</name><value><string>' . $img->get_content_type . '</string></value></member>');
		push(@out,'</struct></value>');
	}
	push(@out,'</data></array>');
	$self->_response(0,join("\n",@out));
}
sub _getmediaobject {
	my $self = shift;
	my $wid  = shift; # string (not use)
	my $iid  = &_value(shift); # string
	my $user = &_value(shift); # string
	my $pass = &_value(shift); # string
	$self->_response(2,undef) if (@_);
	$self->_response(3,undef) if ($self->check_password('user'=>$user,'pass'=>$pass));
	my $image = sb::Data->load('Image','id'=>$iid);
	$self->_response(4,undef) if (!$image);
	$self->_response(7,undef) if (!$self->check_permission('user'=>$image->auth));
	$self->_response(0,'<base64>' . $image->get_as_mime . '</base64>');
}
sub _deletemediaobject {
	my $self = shift;
	my $wid  = shift; # string (not use)
	my $iid  = &_value(shift); # string
	my $user = &_value(shift); # string
	my $pass = &_value(shift); # string
	$self->_response(2,undef) if (@_);
	$self->_response(3,undef) if ($self->check_password('user'=>$user,'pass'=>$pass));
	$self->_response(5,undef) if (!$self->_set_lock);
	my $image = sb::Data->load('Image','id'=>$iid);
	$self->_response(4,undef) if (!$image);
	$self->_response(7,undef) if (!$self->check_permission('user'=>$image->auth));
	$image->erase;
	sb::Data->update($image);
	$self->_response(0,'<boolean>1</boolean>');
}
# ==================================================
# // private functions - utilities
# ==================================================
sub _set_lock {
	my $self = shift;
	return( 1 ) if ($self->{'lock'});
	$self->{'lock'} = sb::Lock->lock or return( undef );
	return( 1 );
}
sub _init_instance {
	my $self = shift;
	$self->{'cat'}  = { sb::Data->load_as_hash('Category') } if (!defined($self->{'cat'}));
	$self->{'ents'} = [sb::Data->load('Entry','sort'=>'date','order'=>0)] if (!defined($self->{'ents'}));
	return($self);
}
sub _sort_categories {
	my $self = shift;
	my %param = (
		'cat'    => [],
		'branch' => undef,   
		@_
	);
	my $list = '';
	foreach my $cat ( @{$param{'cat'}} ) {
		next if (!defined($param{'branch'}) and $cat->main ne '');
		next if ( defined($param{'branch'}) and $cat->main ne $param{'branch'});
		$list .= $cat->id . ',';
		if ($cat->sub ne '') {
			$list .= $self->_sort_categories(
				'cat'    => $param{'cat'},
				'branch' => $cat->id,
			);
		}
	}
	return($list);
}
sub _build_files {
	my $self  = shift;
	my $entry = shift;
	return( undef ) if (!$entry);
	my $type = sb::Config->get->value('conf_entry_archive');
	my $builder = sb::Build->new(
		'time'      => $self->{'time'},
		'user'      => $self->{'users'},
		'cat'       => $self->{'cat'},
		'sortedcat' => [ sort { $b->order <=> $a->order } values(%{$self->{'cat'}}) ],
		'blog'      => sb::Data->load('Weblog','id'=>0),
	);
	$builder->set_entryinfo;
	if ($type eq 'Individual') {
		my @entries = ($entry);
		my @ids = ($entry->id);
		my ($prv,$nxt) = &sb::Admin::Entry::_search_neighbor($self,$entry);
		push(@ids,$prv->id) if ($prv);
		push(@ids,$nxt->id) if ($nxt);
		{ # delete duplication
			my %cnt;
			@ids = grep(!$cnt{$_}++, @ids);
		}
		foreach my $id ( @ids ) {
			next if ($id == $entry->id);
			my $tmp = sb::Data->load('Entry','id'=>$id);
			push(@entries,$tmp) if ($tmp);
		}
		foreach (@mScriptsForEntries) {
			$builder->build_javascript( $_ );
		};
		foreach my $ent ( @entries ) {
			next if ($ent->stat == 0);
			$builder->build_entry( $ent );
		}
	} elsif ($type eq 'Monthly') {
		my $month = sb::Time->format(
			'time'=>$entry->date,
			'form'=>'%Year%%Mon%',
			'zone'=>$entry->tz
		);
		$builder->build_monthly_archive( $month );
	}
	$builder->build_category_index( $entry->cat ) if ($entry->cat ne '');
	$builder->set_latest_entries;
	$builder->build_top_page;
	$builder->build_feedfile('all');
}
sub _edit_entry {
	my $self = shift;
	my %param = (
		'entry'   => undef,
		'content' => {},
		'open'    => 0,
		@_
	);
	my $entry = $param{'entry'};
	my $cont = $param{'content'};
	my $user = $self->{'user'};
	my $blog = sb::Data->load('Weblog','id'=>0);
	my $lang = sb::Language->get;
	my %var = ();
	return( undef ) if (!$user);
	# === preparation ===
	$self->_init_instance;
	$lang->checkcode('',$lang->code_for_charset($self->{'charset'})); # set input charcode
	if ($lang->charset ne $self->{'charset'}) {
		foreach my $elem ('title','description','mt_text_more','mt_excerpt','mt_keywords') {
			$cont->{$elem} = $lang->convert($cont->{$elem},$lang->charcode);
		}
	}
	foreach my $elem ('title','mt_keywords','mt_allow_comments','mt_allow_pings','mt_convert_breaks') {
		$cont->{$elem} =~ tr/\x0D\x0A//d; # removing linefeed
	}
	# === initilize variables ===
	$param{'open'} = 1 if (sb::Config->get->value('basic_xmlpublish'));
	if ($cont->{'dateCreated'}) {
		$cont->{'date'} = sb::Time->convert(
			'year' => $cont->{'dateCreated'}->{'yr'},
			'mon'  => $cont->{'dateCreated'}->{'mo'},
			'day'  => $cont->{'dateCreated'}->{'dy'},
			'hour' => $cont->{'dateCreated'}->{'ho'},
			'min'  => $cont->{'dateCreated'}->{'mi'},
			'sec'  => $cont->{'dateCreated'}->{'sc'},
			'zone' => '+0000',
		);
	} else {
		$cont->{'date'} = $self->{'time'};
	}
	$var{'elem'} = {
		'subj' => $cont->{'title'},
		'cat'  => $user->cat,
		'auth' => $user->id,
		'stat' => $param{'open'},
		'date' => $cont->{'date'},
		'tz'   => sb::Config->get->value('conf_timezone'),
		'edit' => $user->id,
		'acm'  => ($cont->{'mt_allow_comments'} ne '') ? $cont->{'mt_allow_comments'} : $user->get_option('comment'),
		'atb'  => ($cont->{'mt_allow_pings'} ne '') ? $cont->{'mt_allow_pings'} : $user->get_option('trackback'),
		'form' => ($cont->{'mt_convert_breaks'} ne '') ? $cont->{'mt_convert_breaks'} : $user->get_option('format'),
		'body' => sb::Text->detitize($cont->{'description'}),
		'more' => sb::Text->detitize($cont->{'mt_text_more'}),
		'sum'  => $cont->{'mt_excerpt'},
		'key'  => $cont->{'mt_keywords'},
	};
	$var{'tbping'} = ($cont->{'mt_tb_ping_urls'}) ? $cont->{'mt_tb_ping_urls'} : [];
	$var{'ping'} = ($user->get_option('ping')) ? [split('\\n',sb::Config->get->value('conf_edit_ping'))] : [];
	if ($var{'elem'}->{'cat'} ne '' and $self->{'cat'}->{$var{'elem'}->{'cat'}}) {
		$var{'elem'}->{'stat'} = 2 if ($var{'elem'}->{'stat'} and $self->{'cat'}->{$var{'elem'}->{'cat'}}->get_option('top'));
	}
	return( undef ) if ( $self->check_entry_body($var{'elem'}->{'body'}) );
	# === update entry ===
	$entry = sb::Data->add('Entry') if (!$entry); # new entry
	if ($entry) {
		# copy data
		foreach my $elem ( keys(%{$var{'elem'}}) ) {
			$entry->$elem($var{'elem'}->{$elem});
		}
		# send trackback ping
		if ($entry->stat and @{$var{'tbping'}}) {
			my $stat = sb::Ping->new->send_trackback(
				'url'       => $entry->permalink,
				'excerpt'   => $entry->sum,
				'title'     => $entry->subj,
				'blog_name' => $blog->title,
				'list'      => $var{'tbping'},
				'eid'       => $entry->id,
				'now'       => $self->{'time'},
			);
			$entry->add_ping(@{$stat->{'sent'}});
			$entry->tmp(join("\n",@{$stat->{'error'}}));
		}
		# update data and static files
		sb::Data->update($entry);
		$self->_build_files($entry);
		# send update ping
		if ($entry->stat and @{$var{'ping'}}) {
			my $stat = sb::Ping->new->send_update(
				'list' => $var{'ping'},
				'mode' => 'ping',
				'name' => $blog->title,
			);
		}
	}
	return($entry);
}
sub _entry_struct {
	my $self  = shift;
	my %param = (
		'entry' => undef,
		'mode'  => 'basic', # 'basic', 'simple', 'detail'
		@_
	);
	my @out = ();
	my $ent = $param{'entry'};
	my $lang = sb::Language->get;
	$lang->checkcode('',$lang->charcode); # set default charcode
	return( undef ) if (!$ent);
	my $date = sb::Time->format('time'=>$ent->date,'form'=>TIME_FORMAT);
	push(@out,'<struct>');
	push(@out,'<member><name>userid</name><value><string>' . $ent->auth . '</string></value></member>');
	push(@out,'<member><name>dateCreated</name><value><dateTime.iso8601>' . $date . '</dateTime.iso8601></value></member>');
	push(@out,'<member><name>postid</name><value><string>' . $ent->id . '</string></value></member>');
	if ($param{'mode'} ne 'simple') { # 'basic' or 'detail'
		my $subj = $ent->subj;
		$subj = $lang->convert($subj,OUTPUT_CHARCODE) if ($lang->charcode ne OUTPUT_CHARCODE);
		push(@out,'<member><name>title</name><value><string>' . $subj . '</string></value></member>');
	}
	if ($self->check_permission('user'=>$ent->auth)) {
		if ($param{'mode'} eq 'simple') { # for [blogger.getRecentPosts]
			my $body = $ent->entitize('body');
			$body = $lang->convert($body,OUTPUT_CHARCODE) if ($lang->charcode ne OUTPUT_CHARCODE);
			push(@out,'<member><name>content</name><value><string>' . $body . '</string></value></member>');
		}
		if ($param{'mode'} eq 'detail') {
			my $body = $ent->entitize('body');
			my $more = $ent->entitize('more');
			my $word = $ent->key;
			my $sum  = ($ent->entitize('sum') ne '') ? $ent->sum : '';
			my $permalink = $ent->permalink('cat'=>$self->{'cat'});
			if ($lang->charcode ne OUTPUT_CHARCODE) {
				$body = $lang->convert($body,OUTPUT_CHARCODE);
				$more = $lang->convert($more,OUTPUT_CHARCODE);
				$word = $lang->convert($word,OUTPUT_CHARCODE);
				$sum  = $lang->convert($sum ,OUTPUT_CHARCODE);
			}
			push(@out,'<member><name>description</name><value><string>' . $body . '</string></value></member>');
			push(@out,'<member><name>mt_text_more</name><value><string>' . $more . '</string></value></member>');
			push(@out,'<member><name>mt_keywords</name><value><string>' . $word . '</string></value></member>');
			push(@out,'<member><name>mt_excerpt</name><value><string>' . $sum . '</string></value></member>');
			push(@out,'<member><name>link</name><value><string>' . $permalink . '</string></value></member>');
			push(@out,'<member><name>permaLink</name><value><string>' . $permalink . '</string></value></member>');
			push(@out,'<member><name>mt_allow_comments</name><value><string>' . $ent->acm . '</string></value></member>');
			push(@out,'<member><name>mt_allow_pings</name><value><string>' . $ent->atb . '</string></value></member>');
			push(@out,'<member><name>mt_convert_breaks</name><value><string>' . $ent->form . '</string></value></member>');
		}
	} else {
		push(@out,'<member><name>sb_notAuthorized</name><value><boolean>1</boolean></value></member>');
	}
	push(@out,'</struct>');
	return join("\n",@out);
}
# ==================================================
# // private functions - simple xmlrpc parser
# ==================================================
sub _value {
	my $value = shift;
	my $output;
	$value =~ s/<value>(.*)<\/value>/$1/sg; # extract "value"
	$value =~ s/^[\s|\n]*(.*)[\s|\n]*$/$1/s; # extract "real" value
	TYPE_SWITCH: {
		$_ = $value;
		/^<int/ && do {
			if ($value =~ /<int>(.*)<\/int>/s) {
				$output = int($1) ;
				return($output);
			} elsif ($value =~ /<int \/>/s) {
				return();
			}
			last TYPE_SWITCH;
		};
		/^<i4/ && do {
			if ($value =~ /<i4>(.*)<\/i4>/s) {
				$output = int($1) ;
				return($output);
			} elsif ($value =~ /<i4 \/>/s) {
				return();
			}
			last TYPE_SWITCH;
		};
		/^<boolean/ && do {
			if ($value =~ /<boolean>(.*)<\/boolean>/s) {
				$output = int($1) ;
				return($output);
			} elsif ($value =~ /<boolean \/>/s) {
				return();
			}
			last TYPE_SWITCH;
		};
		/^<double/ && do {
			if ($value =~ /<double>(.*)<\/double>/s) {
				$output = $1 ;
				return($output);
			} elsif ($value =~ /<double \/>/s) {
				return();
			}
			last TYPE_SWITCH;
		};
		/^<dateTime\.iso8601/ && do {
			my $check = $1 if ($value =~ /<dateTime\.iso8601>(.*)<\/dateTime\.iso8601>/s);
			if ($check =~ /(\d\d\d\d)-?(\d\d)-?(\d\d)T(\d\d):(\d\d):(\d\d)/) {
				$output = {};
				$output->{'yr'} = $1;
				$output->{'mo'} = $2;
				$output->{'dy'} = $3;
				$output->{'ho'} = $4;
				$output->{'mi'} = $5;
				$output->{'sc'} = $6;
			} else {
				$output = '';
			}
			return($output);
		};
		/^<base64/ && do {
			if ($value =~ /<base64>(.*)<\/base64>/s) {
				require 'mimeutil.pl';
				my $buf = $1;
				$buf =~ s/\s//g; # by KIKUCHI Kouji
				$buf =~ s/(.{76})/$1\n/g;
				$output  = &mimeutil::bodydecode($buf,'b64');
				$output .= &mimeutil::bdeflush('b64');
				return($output);
			} elsif ($value =~ /<base64 \/>/s) {
				return();
			}
			last TYPE_SWITCH;
		};
		/^<struct/ && do {
			$output = {};
			if ($value =~ /<struct>(.*)<\/struct>/s) {
				$output = &_struct($1);
				return($output);
			} elsif ($value =~ /<struct \/>/s) {
				return();
			}
			last TYPE_SWITCH;
		};
		/^<array/ && do {
			$output = [];
			if ($value =~ /<data>(.*)<\/data>/s) {
				$output = &_array($1);
				return($output);
			} elsif ($value =~ /<array \/>/s) {
				return();
			}
			last TYPE_SWITCH;
		};
		/^<string/ && do {
			if ($value =~ /<string>(.*)<\/string>/s) {
				$output = $1 ;
				return($output);
			} elsif ($value =~ /<string \/>/s) {
				return();
			}
			last TYPE_SWITCH;
		};
	}
	$output = $value if (!$output);
	return($output);
}
sub _struct {
	my $input = shift;
	my $output;
	my @stack = ($input =~ /<member>(.*?)<\/member>/sg); # [memo] imperfect regex
	foreach my $member (@stack) {
		if ($member =~ /<name>(.*?)<\/name>.*<value>(.*?)<\/value>/s) {
			my $name = $1;
			my $value = $2;
			$output->{$name} = &_value($value);
		}
	}
	return($output);
}
sub _array {
	my $input = shift;
	my $output;
	my $flag = 0;
	if ($input =~ /<value>[\s|\n]*<struct>/) { # struct in array ?
		my @stack = ($input =~ /<value>[\s|\n]*<struct>(.*?)<\/struct>[\s|\n]*<\/value>/sg); # [memo] imperfect regex
		foreach my $value (@stack) {
			push(@{$output},&_struct($value));
		}
	} else {
		my @stack = ($input =~ /<value>(.*?)<\/value>/sg); # [memo] imperfect regex
		foreach my $value (@stack) {
			push(@{$output},&_value($value));
		}
	}
	return($output);
}
1;
__END__
