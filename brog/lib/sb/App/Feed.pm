# sb::App::Feed - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::App::Feed;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.06';
# 0.06 [2007/04/25] changed _entry to ouput feed_entry_modified correctly
# 0.05 [2005/10/18] changed run to pass TemplateManager object to sb::Content
# 0.04 [2005/08/02] changed run to call sb::Content->output with num
# 0.03 [2005/07/27] changed _entry to convert some fields to avoid an error of parsing xml
# 0.02 [2005/07/11] changed config variable "srv_cgi" to "conf_srv_cgi"
# 0.01 [2005/06/06] changed query to marge into sb.cgi
# 0.00 [2005/05/12] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Interface ();
use sb::Config ();
use sb::Language ();
use sb::TemplateManager ();
use sb::Content ();
use sb::Data ();
use sb::App ();
@ISA = qw( sb::App );
# ==================================================
# // declaration for constant value
# ==================================================
sub DEFAULT_TYPE   (){ 'rss' };
sub CONTENT_TYPE   (){ 'text/xml' };
sub OUTPUT_CHARSET (){ 'utf-8' };
sub OUTPUT_CODE    (){ 'utf8' };
sub LINK_TO_MORE   (){ '<p><a href="%s">%s</a></p>' };
sub TIME_FORMAT    (){ '%Year%-%Mon%-%Day%T%Hour%:%Min%:%Sec%' };
# ==================================================
# // declaration for class member
# ==================================================
my %mFeedTemplate = (
	'rss'  => 'default_rss.rdf',
	'atom' => 'default_atomfeed.xml',
);
my $mFeedPath = undef;
# ==================================================
# // public functions
# ==================================================
sub run { # main routine
	my $class = shift;
	my $self = $class->SUPER::new( @_ );
	my $cgi  = sb::Interface->get;
	my $conf = sb::Config->get;
	my $type = $cgi->value('feed') || DEFAULT_TYPE;
	my $base = sb::TemplateManager->new($self->load_template('file'=>$self->template_name($type)));
	my ($mode,$id,$cond) = &_check_mode($cgi,$conf);
	if ($base ne '') {
		$base = sb::Content->output($base,
			'mode' => $mode,
			'id'   => $id,
			'page' => int( $cgi->value('page') ),
			'cond' => $cond,
			'time' => $self->{'time'},
			'num'  => $conf->value('basic_gen_' . $type),
			'extend' => {
				'main' => {
					'_main'          => \&_common_parts,
					'feed_entrylist' => \&_entrylist,
					'feed_entry'     => \&_entry,
				},
			},
		);
		my $lang = sb::Language->get;
		if ($lang->charcode ne OUTPUT_CODE) { # convert character code
			$lang->checkcode('',$lang->charcode);
			$base = $lang->convert($base,OUTPUT_CODE);
		}
	}
	print $cgi->head('type'=>CONTENT_TYPE,'charset'=>OUTPUT_CHARSET) . $base;
}
sub get_code {
	my $self = shift;
	return( OUTPUT_CODE );
}
sub path {
	my $self = shift;
	$mFeedPath = shift if (@_);
	return($mFeedPath)
}
sub template_name {
	my $self = shift;
	my $type = shift;
	$type = DEFAULT_TYPE if ( !defined($mFeedTemplate{$type}) );
	return( $mFeedTemplate{$type} );
}
# ==================================================
# // private functions - contents extensions
# ==================================================
sub _common_parts {
	my $cms = shift;
	my %var = @_;
	sb::Content::_common_parts($cms,%var);
	$cms->tag('feed_site_encoding'=>OUTPUT_CHARSET);
	$cms->tag('feed_url'=>$mFeedPath);
	$cms->tag('feed_date'=>
		sb::Time->format(
			'time' => $var{'time'},
			'form' => TIME_FORMAT . '+00:00',
			'zone' => '+0000',
			'lang' => 'en'
		)
	);
}
sub _entrylist {
	my $cms = shift;
	my %var = @_;
	my $num = 0;
	foreach my $entry ( @{$var{'entry'}} ) {
		$cms->num($num);
		$cms->tag('feed_list_url'=>$entry->permalink('cat'=>$var{'cat'}));
		$num++;
	}
	return($num);
}
sub _entry {
	my $cms = shift;
	my %var = @_;
	my $num = 0;
	foreach my $entry ( @{$var{'entry'}} ) {
		my $tz = $entry->tz;
		my $body = $entry->formated_body;
		$body =~ s/&(\s|\n)/&amp;$1/g; # avoid an error of parsing xml (imperfect)
		if ($entry->more ne '') {
			$body .= sprintf(LINK_TO_MORE,
				$entry->permalink('cat'=>$var{'cat'},'mode'=>'more'),
				$var{'lang'}->string('parts_more_rss')
			);
		}
		$cms->num($num);
		$cms->tag('feed_entry_url'=>=>$entry->permalink('cat'=>$var{'cat'}));
		$cms->tag('feed_entry_title'=>$entry->subj);
		$cms->tag('feed_entry_summary'=>sb::Text->entitize($entry->sum));
		$cms->tag('feed_entry_description'=>$body);
		if ( $entry->cat ne '' and defined($var{'cat'}->{$entry->cat}) ) { # category
			$cms->tag('feed_entry_category'=>$var{'cat'}->{$entry->cat}->fullname($var{'cat'}));
		} else {
			$cms->tag('feed_entry_category'=>'-');
		}
		$cms->tag('feed_entry_date'=>
			sb::Time->format(
				'time' => $entry->date,
				'form' => TIME_FORMAT . substr($tz,0,3) . ':' . substr($tz,3,2),
				'zone' => $tz,
				'lang' => 'en'
			)
		);
		$cms->tag('feed_entry_modified'=>
			sb::Time->format(
				'time' => $entry->date,
				'form' => TIME_FORMAT . 'Z',
				'zone' => '+0000',
				'lang' => 'en'
			)
		);
		$cms->tag('feed_entry_author'=>$entry->authname($var{'user'}));
		$cms->tag('product_name'=>$sb::PRODUCT);
		$cms->tag('product_webpage'=>$sb::WEBPAGE);
		$cms->tag('site_lang'=>$var{'lang'}->code);
		$num++;
	}
	return($num);
}
# ==================================================
# // private functions
# ==================================================
sub _check_mode { # checking mode
	my ($cgi,$conf) = @_; # input parameters
	my ($mode,$id,$cond); # output parameters
	my $cid = $cgi->value('cid');
	my $tid = $cgi->value('tid');
	$mode = 'ent'  if ($cgi->value('eid') =~ /^\d+$/);   # entry
	$mode = 'cat'  if ($cid =~ /^\d+$/);                 # category
	$mode = 'arc'  if ($cgi->value('month') =~ /^\d+$/); # monthly archive
	$mode = 'arc'  if ($cgi->value('day') =~ /^\d+$/);   # daily archive
	$mode = 'srch' if ($cgi->value('search') ne '');     # search
	$mode = 'page' if ($mode eq '');                     # page mode is default
	# checking id
	$id = $cgi->value('eid') if ($mode eq 'ent');
	$id = $cgi->value('cid') if ($mode eq 'cat');
	# checking filter condition
	$cond = ($cgi->value('month') ne '') ? $cgi->value('month') : $cgi->value('day') if ($mode eq 'arc');
	$cond = $cgi->value('search') if ($mode eq 'srch');
	# generate path
	$mFeedPath  = $conf->value('conf_srv_cgi') . $conf->value('basic_feed');
	$mFeedPath .= ($cgi->value('feed') ne '') ? $cgi->value('feed') : DEFAULT_TYPE;
	$mFeedPath .= '&amp;eid=' . $id if ($mode eq 'ent');
	$mFeedPath .= '&amp;cid=' . $id if ($mode eq 'cat');
	$mFeedPath .= '&amp;month=' . $cond if ($mode eq 'arc' and $cgi->value('month') ne '');
	$mFeedPath .= '&amp;day='   . $cond if ($mode eq 'arc' and $cgi->value('day') ne '');
	$mFeedPath .= '&amp;search=' . &_encode_uri($cond) if ($mode eq 'srch');
	$mFeedPath .= '&amp;page=' . $cgi->value('page') if ($cgi->value('page') =~ /^\d+$/);
	return($mode,$id,$cond);
}
sub _encode_uri { # encode uri
	my $text = shift;
	$text =~ s/(\W)/'%' . unpack('H2', $1)/eg;
	return($text);
}
1;
__END__
