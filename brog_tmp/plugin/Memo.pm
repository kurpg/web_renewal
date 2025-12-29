# sb::Plugin::Memo - Module for sb
# == written by T.Otani <ootani@segausers.gr.jp> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Plugin::Memo;
# ==================================================
# // declaration for global variables
# ==================================================
use vars qw( @ISA );
# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Plugin ();
use sb::Text ();
use sb::Time ();
use sb::Language ();
use sb::Interface ();
use sb::TemplateManager ();
use sb::Text ();
use sb::Build ();
use sb::Admin::Entry ();
@ISA = qw( sb::Admin::Entry );
# ==================================================
# // initialization for plugin
# ==================================================
# register plugin
sb::Plugin->register_plugin(
	'lang' => {
		'ja' => 'euc',
		'en' => 'ascii',
	},
	'text' => {
		'type'    => 'admin, cms',
		'name'    => 'Short Message' . _getname(),
		'text'    => 'Writing short message on the top page.',
		'author'  => 'takkyun',
		'detail'  => 'http://serenebach.net/',
		'version' => version(),
	},
	'file' => 'memo.txt',
	'data' => 1,
);
# register as admin module
sb::Plugin->register_admin_module(
	'mode'   => 'memo' . _getname(),
	'level'  => 1,
	'module' => __PACKAGE__,
);
# register as content module
sb::Plugin->register_content_module(
	'type'     => 'main',
	'callback' => \&_topmemo,
	'field'    => 'topmemo' . _getname(),
);
_initialize_string(); # initialize string
# ==================================================
# // common functions
# ==================================================
sub version
{
	return '0.02';
	# 0.02 [2008/03/06] modified structure to consider package name
}
sub _getname
{
	my $name = __PACKAGE__;
	return $1 if ($name =~ /(\d+$)/);
	return;
}
sub _initialize_string
{
	my $string = sb::Language->get->string('mode_memo' . _getname());
	$string .= _getname();
	sb::Language->get->string('mode_memo' . _getname() => $string);
}
# ==================================================
# // functions for content
# ==================================================
sub _topmemo
{
	my $cms = shift;
	my %var = @_;
	my $data = sb::Plugin->get_data;
	return( 0 ) if ($var{'mode'} ne 'page' or $var{'page'} != 0 or !$data); # not top page
	my $date = sb::Time->format(
		'time'=>$data->date,
		'form'=>$var{'conf'}->value('conf_entry_date') . ' ' . $var{'conf'}->value('conf_entry_time'),
		'zone'=>$var{'conf'}->value('conf_timezone'),
		'lang'=>$var{'conf'}->value('conf_time_lang')
	);
	my $memo = ($data->setting ne 'on') 
	         ? sb::Text->format('text'=>$data->data,'form'=>1) 
	         : $data->data;
	$cms->num(0);
	$cms->tag('sb_memo' . _getname() =>$memo);
	$cms->tag('sb_memo' . _getname() . '_time'=>$date);
	return( 1 );
}
# ==================================================
# // declaration for constant value
# ==================================================
sub TEMPLATE (){ 'memo.html' };
# ==================================================
# // public functions - callback
# ==================================================
sub callback
{ # callbacks
	my $self = shift;
	return ( $self->{'regi'} ) 
		? $self->_save_memo(@_)
		: $self->_open_memo(@_);
}
# ==================================================
# // private functions - main routine
# ==================================================
sub _save_memo
{
	my $self = shift;
	my %param = ( 'message' => '', @_ );
	my $cgi  = sb::Interface->get;
	my $data = sb::Plugin->get_data;
	$data->data($cgi->value('topmemo'));
	$data->setting($cgi->value('topmemo_breaks'));
	$data->date($self->{'time'});
	sb::Plugin->set_data('data'=>$data);
	$self->{'cat'} = { sb::Data->load_as_hash('Category') };
	my $builder = sb::Build->new(
		'time'      => $self->{'time'},
		'user'      => $self->{'users'},
		'cat'       => $self->{'cat'},
		'sortedcat' => [ sort { $b->order <=> $a->order } values(%{$self->{'cat'}}) ],
		'blog'      => sb::Data->load('Weblog','id'=>0),
	);
	$builder->build_top_page;
	return $self->_open_memo('message'=>sb::Language->get->string('parts_editcomp'));
}
sub _open_memo
{
	my $self = shift;
	my %param = ( 'message' => '', @_ );
	my $cgi  = sb::Interface->get;
	my $cms  = sb::TemplateManager->new(sb::Plugin->load_template('file'=>TEMPLATE));
	my $data = sb::Plugin->get_data;
	$self->common_template_parts($cms);
	$cms->num(0);
	$cms->tag('sb_topmemo_breaks' => ($data->setting ne '') ? 'checked="checked"' : '');
	$cms->tag('sb_topmemo'        => sb::Text->entitize($data->data));
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
	if ($param{'message'} ne '')
	{
		$cms->num(0);
		$cms->tag('sb_process_message'=>$param{'message'});
		$cms->block('sb_process_message'=>1);
	}
	$cms->num(0);
	$cms->tag('sb_memomode'=>_getname());
	return sb::Interface->get->head('type'=>'text/html') . $self->set_main($cms->output);
}
1;
__END__
