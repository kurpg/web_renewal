# sb::Language::en - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Language::en;

use strict;
use Carp;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.01';
# 0.01 [2006/11/09] added error_dup_catidx
# 0.00 [2005/01/17] created

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Language ();
@ISA = qw( sb::Language );
# ==================================================
# // constructor
# ==================================================
sub get
{
	my $class = shift;
	my $self = $class->SUPER::get();
	$self->_init(); # initialize
	return($self);
}
sub new
{
	&get; # 'new' is alias for 'get'
}
# ==================================================
# // private functions
# ==================================================
sub _init
{
	my $self = shift;
	return() if ( $self->charset );
	$self->charset('UTF-8');
	$self->charcode('utf8');
	# Selecting time stamp style
	$self->string('disptime_JUGEM'   => 'JUGEM compatible');
	$self->string('disptime_EngLong' => 'English');
	$self->string('disptime_EngShrt' => 'English (shortened)');
	$self->string('disptime_French'  => 'French');
	$self->string('disptime_EngNum'  => 'Japanese (day in English)');
	$self->string('disptime_JpnNum'  => 'Japanese');
	$self->string('disptime_LstYear' => 'Year also shown in artcile list of my weblog');
	$self->string('disptime_LstNone' => 'No date shown in artcile list of my weblog');
	# Selecting language
	$self->string('language_ja' => 'Japanese');
	$self->string('language_en' => 'English');
	$self->string('language_fr' => 'French');
	# Saving files
	$self->string('entryarchive_Individual' => 'Save individual article in html format');
	$self->string('entryarchive_Monthly'    => 'Save monthly archive in html format');
	$self->string('entryarchive_None'       => 'Generate html file for top page');
	# General settings
	$self->string('setup_aws_stat'       => 'Closed:Open');
	$self->string('setup_msg_stat'       => 'Not confirmed:Confirmed');
	$self->string('setup_link_stat'      => 'Open:Closed');
	$self->string('setup_edit_stat'      => 'Closed:Open');
	$self->string('setup_edit_format'    => 'No text formatting:Auto line breaking');
	$self->string('setup_edit_date'      => 'Do not update when edited:Update when edited');
	$self->string('setup_edit_comment'   => 'Refuse:Accept:Confirm to open');
	$self->string('setup_edit_trackback' => 'Refuse:Accept:Confirm to open');
	# Recommending items
	$self->string('aws_genre_books-jp'       => 'Books (in Japanese)');
	$self->string('aws_genre_books-us'       => 'Books');
	$self->string('aws_genre_music-jp'       => 'Popular music (in Japanese)');
	$self->string('aws_genre_classical-jp'   => 'Classical music (in Japanese)');
	$self->string('aws_genre_dvd-jp'         => 'DVD (in Japanese)');
	$self->string('aws_genre_vhs-jp'         => 'VHS (in Japanese)');
	$self->string('aws_genre_electronics-jp' => 'Electronics (in Japanese)');
	$self->string('aws_genre_kitchen-jp'     => 'Home&amp;Kitchen (in Japanese)');
	$self->string('aws_genre_software-jp'    => 'Software (in Japanese)');
	$self->string('aws_genre_videogames-jp'  => 'Video games (in Japanese)');
	$self->string('aws_genre_toys-jp'        => 'Toys &amp;Hobby (in Japanese)');
	$self->string('aws_genre_asin'           => 'ASIN/ISBN');
	# Administration
	$self->string('mode_new'       => 'New article');
	$self->string('mode_edit'      => 'Saved articles');
	$self->string('mode_list'      => 'Article list');
	$self->string('mode_upload'    => 'File uploading');
	$self->string('mode_amazon'    => 'Affiliate program');
	$self->string('mode_category'  => 'Categories');
	$self->string('mode_link'      => 'Links');
	$self->string('mode_profile'   => 'User profile');
	$self->string('mode_view'      => 'View my weblog');
	$self->string('mode_rebuild'   => 'Rebuilding');
	$self->string('mode_comment'   => 'Comments');
	$self->string('mode_trackback' => 'Trackbacks');
	$self->string('mode_refuse'    => 'Junk filter');
	$self->string('mode_user'      => 'User registration');
	$self->string('mode_template'  => 'Templates');
	$self->string('mode_config'    => 'Configuration');
	$self->string('mode_editor'    => 'Editor settings');
	$self->string('mode_help'      => 'Help');
	$self->string('mode_access'    => 'Access analyzer');
	$self->string('mode_status'    => 'Status');
	$self->string('mode_logout'    => 'Log out');
	$self->string('mode_login'     => 'Log in');
	$self->string('mode_welcome'   => 'Welcome');
	$self->string('mode_bm'        => 'Short message');
	$self->string('mode_edittemp'  => 'Template editor');
	$self->string('mode_edituser'  => 'User info editor');
	# Message parts
	$self->string('parts_noname'   => '[No name given]');
	$self->string('parts_notitle'  => '[No title given]');
	$self->string('parts_arrow'    => '=&gt;');
	$self->string('parts_sequel'   => 'Read more&gt;&gt;');
	$self->string('parts_more_rss' => '[More]');
	$self->string('parts_com_num'  => 'Comments ');
	$self->string('parts_tb_num'   => 'Trackbacks ');
	$self->string('parts_mailchar' => 'ascii'); # code for mail
	$self->string('parts_no_cat'   => 'Not categorized');
	$self->string('parts_thumb'    => ' (Thumbnail)');
	$self->string('parts_withlink' => ' (Link)');
	$self->string('parts_thumblst' => ' [*]');
	$self->string('parts_advuser'  => ' [*]');
	$self->string('parts_tmpinfo'  => ' [*]');
	$self->string('parts_formdate' => 'Year%Year% Month%Mon% Day%Day%');
	$self->string('parts_formtime' => '%Hour%:%Min%:%Sec%');
	$self->string('parts_error'    => 'Error:');
	$self->string('parts_logout'   => 'You have been logged out successfully.');
	$self->string('parts_sentping' => 'Sent PING to<br />');
	$self->string('parts_findtb'   => 'trackback URLs found');
	$self->string('parts_deleted'  => 'posts deleted');
	$self->string('parts_confcomp' => 'Changes of your setting reflected<br />');
	$self->string('parts_needmake' => 'You need to rebuild your weblog to reflect the changes to the previous articles.');
	$self->string('parts_rec_make' => 'You need to rebuild your weblog to reflect the changes completely.');
	$self->string('parts_link_bld' => '&#8658;<a href="%s?__mode=rebuild">Rebuild site</a><br />');
	$self->string('parts_buildcmp' => 'Your weblog rebuilt.  Confirm your site by clicking &quot;View my weblog&quot;.');
	$self->string('parts_passchng' => 'Your password changed.  Log in again to continue.<br />');
	$self->string('parts_userchng' => 'Your user ID changed.  Log in again to continue.<br />');
	$self->string('parts_editcomp' => 'Edited');
	$self->string('parts_new_comp' => 'Your request has been processed');
	$self->string('parts_add_comp' => 'Added %d objects.<br />');
	$self->string('parts_sw_on'    => 'Open');
	$self->string('parts_sw_off'   => 'Close');
	$self->string('parts_showfile' => '[Details...]');
	$self->string('parts_bm_close' => '[Close]');
	$self->string('parts_tempedit' => 'Edit');
	$self->string('parts_temp_use' => 'In use');
	$self->string('parts_temp_can' => '-');
	$self->string('parts_temp_sel' => 'Template to use changed<br />');
	$self->string('parts_temp_css' => 'CSS template reflected');
	$self->string('parts_temp_add' => 'This template saved');
	$self->string('parts_tempcomp' => 'HTML template updated<br />');
	$self->string('parts_no_icon'  => 'No icon confirmed');
	$self->string('parts_build_op' => '[#%d] Archive rebuilt (Recent:%d-%d)');
	$self->string('parts_subj_tb'  => '[Pukeko]Trackback notified');
	$self->string('parts_subj_com' => '[Pukeko]Comment notified');
	$self->string('parts_body_tb'  => 'Trackback received');
	$self->string('parts_body_com' => 'Comment received');
	$self->string('parts_extracat' => '<script type="text/javascript">showCategorySelector(\'Related categories ...\',\'Hide related categories\');</script>');
	$self->string('parts_not_inst'=>'<strong style="color:red">%s is NOT installed.</strong>');
	$self->string('parts_install' =>'<strong style="color:green">%s is installed.</strong>');
	$self->string('parts_no_file' =>'<strong style="color:red">&quot;%s&quot; does NOT exist.</strong>');
	$self->string('parts_unread'  =>'<strong style="color:red">&quot;%s&quot; is NOT readable.  Please check its permission.</strong>');
	$self->string('parts_unwrite' =>'<strong style="color:red">&quot;%s&quot; is NOT writable.  Please check its permission.</strong>');
	$self->string('parts_finefile'=>'<strong style="color:green">&quot;%s&quot; is placed correctly.</strong>');
	# Error messages
	$self->string('error_not_allow'   => 'Not authorized');
	$self->string('error_wrong_text'  => 'Invalid characters');
	$self->string('error_wrong_pass'  => 'Incorrect password');
	$self->string('error_file_open'   => 'Unable to open file : ');
	$self->string('error_unsuppoted'  => 'Not supported : ');
	$self->string('error_unknown'     => 'Unknown error occurred.');
	$self->string('error_file_lock'   => 'File locked');
	$self->string('error_initialize'  => 'Initial authentification failed.  Install Serene Bach program again.');
	$self->string('error_expired'     => 'Timeout error.  Log in again to continue.');
	$self->string('error_difference'  => 'Invalid login information entered');
	$self->string('error_no_user'     => 'No such user');
	$self->string('error_no_entry'    => 'No such article');
	$self->string('error_exist_user'  => 'This user name already used');
	$self->string('error_import_cond' => 'No password for new user confirmed');
	$self->string('error_no_body'     => 'No article body');
	$self->string('error_banned'      => 'Article posting banned');
	$self->string('error_doubled'     => 'Already posted');
	$self->string('error_no_comment'  => 'No comment body');
	$self->string('error_wait_msg'    => 'Thank you for your comment.  Your comment will be shown on my weblog upon approval by weblog master.');
	$self->string('error_res_msg'     => 'Acknowledgement receipt of your comment');
	$self->string('error_exist_cat'   => 'This category already exists');
	$self->string('error_res_msg'     => 'Notification Process Result for a comment');
	$self->string('error_failtoadd'   => 'Failed to add obejcts.');
	$self->string('error_inst_skipped'  =>'999 Skipped');
	$self->string('error_inst_load_temp'=>'Fait to load the template.');
	$self->string('error_inst_init'     =>'Fail to initialize installation.');
	$self->string('error_installing'    =>'Unknown error occured during installaion.');
	$self->string('error_alredy_inst'   =>'The weblog has been setup already.');
	$self->string('error_dup_catidx'    =>'Stored directory for category index is duplicated with other category.[%s]<br />');
	return();
}
1;
