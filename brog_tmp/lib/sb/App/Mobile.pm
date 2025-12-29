# sb::App::Mobile - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::App::Mobile;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.05';
# 0.05 [2007/04/12] changed run to output Content-Length correctly
# 0.04 [2006/12/15] changed _check_mode to fix a bug
# 0.03 [2005/10/18] changed load_template and run to pass TemplateManager object to sb::Content
# 0.02 [2005/10/15] changed _mobile_top, _mobile_comment_area, _mobile_trackback_area. Thanks Fuco!
# 0.01 [2005/08/15] changed _check_mode to extract entries correctly
# 0.00 [2005/06/09] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Interface ();
use sb::Config ();
use sb::Language ();
use sb::Data ();
use sb::TemplateManager ();
use sb::Content ();
use sb::Receipt ();
use sb::App ();
@ISA = qw( sb::App );
# ==================================================
# // declaration for constant value
# ==================================================
sub OUTPUT_CHARSET    (){ 'Shift_JIS' };
sub OUTPUT_CODE       (){ 'sjis' };
sub DEFAULT_TEMPLATE  (){ 'default_mobile.html' };
sub DEFAULT_TEXT_SIZE (){ 2048 };
sub MOBILE_TAGS       (){ 'BR|A|Q|IMG|EM|STRONG|H\d|P|DIV|[O|U|D]L|LI|DT|DD|BLOCKQUOTE|FORM|INPUT|SELECT|OPTION|HR|DEL|PRE' };
sub ENTRY_LINK        (){ '<a href="%s" accesskey="%s">[%s] %s</a> ' };
sub COMMENTFORM_LINK  (){ 'comment form' };
sub BODY_LINK         (){ 'beginning...' };
sub MORE_LINK         (){ 'more...' };
sub PREV_ARROW        (){ '&lt;&lt;' };
sub NEXT_ARROW        (){ '&gt;&gt;' };
# ==================================================
# // declaration for class member
# ==================================================
my $mMobileMode = undef;
my $mMobilePage = 0;
my $mUserAgent  = undef;
my $mMobileNum  = 0;
my $mMobileMore = undef;
# ==================================================
# // public functions
# ==================================================
sub run { # main routine
	my $class = shift;
	my $self  = $class->SUPER::new( @_ );
	my $cgi   = sb::Interface->get;
	my $conf  = sb::Config->get;
	my $base  = $self->load_template;
	my @entry = &_check_mode($cgi,$conf);
	if ($mMobileMode eq 'com') {
		print sb::Receipt->new(
			'mode' => 'com',
			'cgi'  => $cgi,
			'id'   => $cgi->value('entry_id'),
			'time' => $self->{'time'},
		)->issue;
	} else {
		print $self->error('no template') if ($base eq '');
		my $output = sb::Content->output(sb::TemplateManager->new($base),
			'mode'      => 'mob',
			'css'       => undef,
			'page'      => ($mMobileMode eq 'page' or $mMobileMode eq 'cat') ? $mMobilePage : undef,
			'id'        => $cgi->value('eid'),
			'time'      => $self->{'time'},
			'entry'     => \@entry,
			'entry_num' => sb::Data->matched,
			'extend' => {
				'main' => {
					'_main'                 => \&_mobile_common_parts,
					'mobile_xmldeclaration' => \&_mobile_xmldeclaration,
					'mobile_top'            => \&_mobile_top,
					'mobile_entry'          => \&_mobile_entry,
					'mobile_comment_area'   => \&_mobile_comment_area,
					'mobile_comment_form'   => \&_mobile_comment_form,
					'mobile_trackback_area' => \&_mobile_trackback_area,
				},
			},
		);
		my $lang = sb::Language->get;
		if ($lang->charcode ne OUTPUT_CODE) { # convert character code
			$lang->checkcode('',$lang->charcode);
			$output = $lang->convert($output,OUTPUT_CODE);
		}
		print $cgi->head('type'=>'text/html','charset'=>OUTPUT_CHARSET,'length'=>length($output)) . $output;
	}
}
sub load_template {
	my $self = shift;
	my $base = undef;
	my $temp = undef;
	if (sb::Config->get->value('conf_mobile_temp') > -1) {
		$temp = sb::Data->load('Template','id'=>sb::Config->get->value('conf_mobile_temp'));
	}
	$base = ($temp) ? $temp->main : $self->SUPER::load_template('file'=>DEFAULT_TEMPLATE);
	return($base);
}
# ==================================================
# // private functions - contents extensions
# ==================================================
sub _mobile_common_parts {
	my $cms = shift;
	my %var = @_;
	&sb::Content::_common_parts($cms,%var);
	$cms->tag('site_encoding'=>OUTPUT_CHARSET);
	return(1);
}
sub _mobile_xmldeclaration {
	my $cms = shift;
	my %var = @_;
	return ($mUserAgent =~ /DoCoMo/) ? 0 : 1;
}
sub _mobile_top {
	my $cms = shift;
	my %var = @_;
	return(0) if ( $mMobileMode ne 'page' and $mMobileMode ne 'cat' );
	&sb::Content::_title($cms,%var);
	&sb::Content::_list_selected($cms,%var);
	$var{'id'} = sb::Interface->get->value('cid') if ($mMobileMode eq 'cat'); # set parameter temporarily
	&sb::Content::_page($cms,%var);
	return(1);
}
sub _mobile_entry {
	my $cms   = shift;
	my %var   = @_;
	my $entry = $var{'entry'}->[0];
	return(0) if ( $mMobileMode ne 'ent' );
	return(0) if ( !$entry );
	my $funcs = &sb::Content::Entry::_init();
	$funcs->{'body_text'} = \&_mobile_entry_body;
	foreach my $label (keys %{ $funcs } ) {
		next if ($label eq '_main');
		eval{ &{$funcs->{$label}}($cms,$entry,%var) };
	}
	return(1);
}
sub _mobile_entry_body {
	my $cms   = shift;
	my $entry = shift;
	my %var   = @_;
	my $permalink = $entry->permalink('type'=>'Mobile');
	my $nxt  = $mMobilePage;
	my $body = (!$mMobileMore) ? $entry->formated_body : $entry->formated_more;
	$body = sb::Text->remove_tag(
		'text'  => $body,
		'code'  => sb::Language->get->charcode,
		'allow' => MOBILE_TAGS,
	);
	$body = &_mobile_change_tags($body);
	($body,$nxt) = &_mobile_paging_entry($body,$mMobilePage) if (length($body) > DEFAULT_TEXT_SIZE);
	$cms->tag('entry_description'=>$body);
	$cms->tag('entry_excerpt'=>$entry->sum);
	# entry links
	my $mark = (!$mMobileMore) ? '&amp;page=' : '&amp;more=';
	my $navi = '';
	if ($nxt > $mMobilePage) {
		$navi .= sprintf(ENTRY_LINK,$permalink . $mark . ($mMobilePage - 1),'7','7',PREV_ARROW) if ($mMobilePage > 0);
		$navi .= sprintf(ENTRY_LINK,$permalink,'7','7',BODY_LINK) if ($mMobilePage == 0 and $mMobileMore);
		$navi .= sprintf(ENTRY_LINK,$permalink . $mark . $nxt,'9','9',NEXT_ARROW);
	} else {
		$navi .= sprintf(ENTRY_LINK,$permalink . $mark . ($mMobilePage - 1),'7','7',PREV_ARROW) if ($mMobilePage > 0);
		if (!$mMobileMore and $entry->more ne '') {
			$navi .= sprintf(ENTRY_LINK,$entry->permalink('type'=>'Mobile','mode'=>'more'),'9','9',MORE_LINK);
		} elsif ($mMobileMore and $mMobilePage == 0) {
			$navi .= sprintf(ENTRY_LINK,$permalink,'7','7',BODY_LINK);
		}
	}
	$cms->tag('entry_link'=>$navi);
}
sub _mobile_comment_area {
	my $cms = shift;
	my %var = @_;
	my $entry = $var{'entry'}[0];
	return(0) if ( $mMobileMode ne 'msg' );
	return(0) if (!$entry);
	return(0) if ($entry->acm == 0);
	my @comments = &_mobile_paging_attachment(
		sb::Data->load('Message',
			'sort'   => 'date',
			'cond'   => {'stat'=>1,'eid'=>$var{'id'}},
			'order'  => $var{'conf'}->value('conf_com_sort'),
			'detail' => 'on',
		)
	);
	for (my $i=0;$i<@{$comments[$mMobilePage]};$i++) {
		my $com = $comments[$mMobilePage]->[$i];
		$cms->num($i);
		&sb::Content::Message::_content($cms,$com,%var);
		my $body = $com->formated_body;
		$body =~ s/&amp;(#\d*?;)/&$1/g; # displaying pictorial letters
		$cms->tag('comment_description'=>$body);
	}
	$cms->block('comment'=>($#{$comments[$mMobilePage]} + 1));
	$cms->num(0);
	$cms->tag('entry_link'=>sprintf(ENTRY_LINK,$entry->permalink('type'=>'Mobile'),'2','2',$entry->subj));
	$cms->tag('comment_form'=>
		sprintf(ENTRY_LINK,$entry->permalink('type'=>'Mobile','mode'=>'form'),'5','5',COMMENTFORM_LINK)
	);
	my $permalink = $entry->permalink('type'=>'Mobile');
	my $navi = '';
	my $mark = '&amp;com=';
	$navi .= sprintf(ENTRY_LINK,$permalink . $mark . ($mMobilePage - 1),'7','7',PREV_ARROW) if ($mMobilePage > 0);
	$navi .= sprintf(ENTRY_LINK,$permalink . $mark . ($mMobilePage + 1),'9','9',NEXT_ARROW) if ($mMobilePage < $#comments);
	$cms->tag('comment_link'=>$navi);
	return(1);
}
sub _mobile_comment_form {
	my $cms = shift;
	my %var = @_;
	my $entry = $var{'entry'}[0];
	return(0) if ( $mMobileMode ne 'form' );
	return(0) if (!$entry);
	return(0) if ($entry->acm == 0);
	$cms->num(0);
	$cms->tag('comment_num'=>
		sprintf(ENTRY_LINK,
			$entry->permalink('type'=>'Mobile','mode'=>'com'),
			'5',
			'5',
			$var{'lang'}->string('parts_com_num') . ' (' . $entry->com . ')'
		)
	);
	$cms->tag('entry_link'=>sprintf(ENTRY_LINK,$entry->permalink('type'=>'Mobile'),'2','2',$entry->subj));
	$cms->tag('entry_id'=>$entry->id);
	return(1);
}
sub _mobile_trackback_area {
	my $cms = shift;
	my %var = @_;
	my $entry = $var{'entry'}[0];
	return(0) if ( $mMobileMode ne 'tb' );
	return(0) if (!$entry);
	return(0) if ($entry->atb == 0);
	my @trackbacks = &_mobile_paging_attachment(
		sb::Data->load('Trackback',
			'sort'   => 'date',
			'cond'   => {'stat'=>1,'eid'=>$var{'id'}},
			'order'  => $var{'conf'}->value('conf_tb_sort'),
			'detail' => 'on',
		)
	);
	for (my $i=0;$i<@{$trackbacks[$mMobilePage]};$i++) {
		my $tb = $trackbacks[$mMobilePage]->[$i];
		$cms->num($i);
		&sb::Content::Trackback::_content($cms,$tb,%var);
	}
	$cms->block('trackback'=>($#{$trackbacks[$mMobilePage]} + 1));
	$cms->num(0);
	$cms->tag('entry_link'=>sprintf(ENTRY_LINK,$entry->permalink('type'=>'Mobile'),'2','2',$entry->subj));
	my $permalink = $entry->permalink('type'=>'Mobile');
	my $navi = '';
	my $mark = '&amp;tb=';
	$navi .= sprintf(ENTRY_LINK,$permalink . $mark . ($mMobilePage - 1),'7','7',PREV_ARROW) if ($mMobilePage > 0);
	$navi .= sprintf(ENTRY_LINK,$permalink . $mark . ($mMobilePage + 1),'9','9',NEXT_ARROW) if ($mMobilePage < $#trackbacks);
	$cms->tag('trackback_link'=>$navi);
	return(1);
}
# ==================================================
# // private functions - contents utilities
# ==================================================
sub _mobile_paging_entry {
	my ($text,$page) = @_; # input parameters / $page works as output parameter as well
	my $output = '';       # output parameter
	my @lines = split("\n",$text);
	my @tags = ();
	my $cnt  = 0;
	my $size = 0;
	my $bgn  = $page * DEFAULT_TEXT_SIZE;
	my $end  = ($page + 1) * DEFAULT_TEXT_SIZE;
	foreach my $line (@lines) {
		my @check = ($line =~ /<(.*?)>/g);
		if ($size >= $bgn and $size < $end) {
			if ($output eq '' and $#tags > -1) {
				foreach (@tags) {
					$output .= '<' . $_ . '>';
				}
			}
			$output .= $line . "\n";
		}
		foreach my $tag (@check) {
			next if (index($tag,'\!') == 0 or index($tag,'\?') == 0);
			next if (index($tag,'/') > 0);
			next if ($tag =~ /^(a|br|hr)/i); # empty elements and anchors
			if (index($tag,'/') == -1) {
				$tag = lc((split(/\s/,$tag))[0]);
				push(@tags,$tag);
				next;
			} elsif (index($tag,'/') == 0) {
				$tag =~ tr/\///d;
				$tag = lc($tag);
				pop(@tags) if ($tags[$#tags] eq $tag);
			}
		}
		$size += length($line);
		if ($size > $end) {
			if ($#tags > -1) {
				@tags = reverse(@tags);
				foreach (@tags) {
					$output .= '</' . $_ . '>';
				}
			}
			last;
		}
		$cnt++;
	}
	$output = $lines[$cnt] if ($output eq '');
	$page++ if ($cnt < $#lines);
	return($output,$page);
}
sub _mobile_change_tags {
	my $text = shift;
	$text =~ s/<a(.*?)href\s?=\s?"(.*?)"((?:(?!<\/a>))*?)><img (.*?)alt\s?=\s?"(.*?)"(.*?)><\/a>/<a href="$2">image[$5]<\/a>/sgi; # by trip_eye
	$text =~ s/<img (.*?)src\s?=\s?"(.*?)"(.*?)alt\s?=\s?"(.*?)"(.*?)>/<a href="$2">image[$4]<\/a>/sgi;
	$text =~ s/<img (.*?)alt\s?=\s?"(.*?)"(.*?)src\s?=\s?"(.*?)"(.*?)>/<a href="$4">image[$2]<\/a>/sgi;
	$text =~ s/<img (.*?)src\s?=\s?"(.*?)"(.*?)>/<a href="$2">image<\/a>/sgi;
	$text =~ s/<\/?q(.*?)>/&quot;/sgi;
	$text =~ s/<del(.*?)<\/del>//sgi;
	return($text);
}
sub _mobile_paging_attachment {
	my @objs = @_;
	my @page = ([]);
	my $size = 0;
	my $cnt  = 0;
	for (my $i=0;$i<@objs;$i++) {
		$size += $objs[$i]->get_size;
		push(@{$page[$cnt]},$objs[$i]);
		if ($size >= DEFAULT_TEXT_SIZE) {
			$cnt++;
			$size = 0;
			$page[$cnt] = [];
		}
	}
	return(@page);
}
# ==================================================
# // private functions
# ==================================================
sub _check_mode { # checking mode and extracting entries
	my ($cgi,$conf) = @_; # input parameters
	my @entry = ();       # output parameter
	$mMobileMode = 'ent'  if ($cgi->value('eid') =~ /^\d+$/);      # entry
	$mMobileMode = 'cat'  if ($cgi->value('cid') =~ /^\d+$/);      # category
	$mMobileMode = 'com'  if ($cgi->value('entry_id') =~ /^\d+$/); # receiving comment
	$mMobileMode = 'page' if ($mMobileMode eq '');                 # page mode is default
	$mMobilePage = int( $cgi->value('page') );
	$mUserAgent  = $cgi->value('_agnt');
	if ($mMobileMode ne 'com') { # extracting entries
		my $id   = undef;
		my $page = ($mMobileMode eq 'ent') ? undef : $mMobilePage;
		my $num  = ($conf->value('conf_entry_disp') < 1) ? undef : $conf->value('conf_entry_disp');
		$page = -1 if ($conf->value('conf_entry_disp') < 1);
		$id = int($cgi->value('eid')) if ($mMobileMode eq 'ent');
		$id = int($cgi->value('cid')) if ($mMobileMode eq 'cat');
		@entry = sb::Content::_extract_entry(
			'mode' => $mMobileMode,
			'id'   => $id,
			'page' => $page,
			'conf' => $conf,
			'cond' => undef,
			'num'  => $num,
		);
	}
	# for entry mode
	if ($mMobileMode eq 'ent')
	{
		if ($cgi->value('form') ne '')
		{ # comment form
			$mMobileMode = 'form';
			$mMobilePage = 0;
		}
		elsif ($cgi->value('com') ne '')
		{ # comments
			$mMobileMode = 'msg';
			$mMobilePage = int( $cgi->value('com') );
		}
		elsif ($cgi->value('tb') ne '')
		{ # trackbacks
			$mMobileMode = 'tb';
			$mMobilePage = int( $cgi->value('tb') );
		}
		elsif ($cgi->value('more') ne '')
		{ # entry sequel mode
			$mMobileMore = 1;
			$mMobilePage = int( $cgi->value('more') );
		}
	}
	return(@entry);
}
1;
__END__
