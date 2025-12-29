# sb::Admin::Amazon - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Admin::Amazon;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.06';
# 0.06 [2006/07/22] changed _display_amazon_list to use new sb::Aws
# 0.05 [2006/09/30] changed _update_amazon to check permission
# 0.04 [2005/07/26] changed _update_amazon to add new ordering function
# 0.03 [2005/07/25] changed _display_amazon_list to use sb::Aws->mode_table
# 0.02 [2005/07/20] changed _is_editable to fix a bug
# 0.01 [2005/06/30] changed _display_image to add alt and title attribute to img tag
# 0.00 [2005/02/02] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Config ();
use sb::Language ();
use sb::Interface ();
use sb::TemplateManager ();
use sb::Data ();
use sb::Text ();
use sb::Aws ();
use sb::Admin::Entry ();
@ISA = qw( sb::Admin::Entry );
# ==================================================
# // declaration for constant value
# ==================================================
sub TEMPLATE        (){ 'amazon.html' };
sub LIST_COLUMN     (){ 4 };
sub MYLIST_COLUMN   (){ 7 };
sub DISPLAY_NUMBER  (){ 10 };
sub ITEM_LENGTH     (){ 40 };
sub NO_IMAGE        (){ '&nbsp;' };
sub DENIED_CHECK    (){ '-' };
sub DEFAULT_COLUMN  (){ '-' };
sub SUFFIX_AUTHOR   (){ ' ...' };
sub ORDER_LEFT      (){ '<input type="submit" name="up%d" value="&#9650;" class="updown" />' };
sub ORDER_RIGHT     (){ '<input type="submit" name="dn%d" value="&#9660;" class="updown" />' };
sub ORDER_COLUMN    (){ '%s</td><td>%s' };
# ==================================================
# // declaration for class member
# ==================================================
# ==================================================
# // public functions - callback
# ==================================================
sub callback
{
	my $self = shift;
	return ($self->{'regi'}) 
		? $self->_update_amazon(@_) 
		: $self->_display_amazon_list(@_);
}
# ==================================================
# // private functions - main routine
# ==================================================
sub _update_amazon
{
	my $self = shift;
	my %param = ( 'message' => '', @_ );
	my $cgi = sb::Interface->get;
	my $lang = sb::Language->get;
	my $msg = '';
	if ($cgi->value('__regi') eq 'add')
	{ # add new recommended item
		my $creator = $cgi->value('aws_cre');
		$creator =~ s/&sb;/\n/g; # remove special escape chars
		my $url = $cgi->value('aws_url');
		$url = $1 if ($url =~ /(.*?)\?.+$/);
		my %elem = (
			'pid'  => ( $self->{'user'} ) ? $self->{'user'}->id : 0, # presenter
			'stat' => 1,                                             # status
			'name' => sb::Text->entitize($cgi->value('aws_name')),   # prudct name
			'cat'  => sb::Text->entitize($cgi->value('aws_cat')),    # catalog / pruduct group
			'cre'  => sb::Text->entitize($creator),                  # creator(s)
			'days' => sb::Text->entitize($cgi->value('aws_days')),   # release date
			'make' => sb::Text->entitize($cgi->value('aws_make')),   # manufacturer
			'ism'  => $cgi->value('aws_ism'),                        # small image
			'imd'  => $cgi->value('aws_imd'),                        # medium image
			'ilg'  => $cgi->value('aws_ilg'),                        # large image
			'ava'  => sb::Text->entitize($cgi->value('aws_ava')),    # [deprecated] availability
			'lpr'  => sb::Text->entitize($cgi->value('aws_lpr')),    # list price
			'opr'  => sb::Text->entitize($cgi->value('aws_opr')),    # offer price
			'msg'  => sb::Text->entitize($cgi->value('aws_msg')),    # presenter's comments
			'url'  => $url,                                          # product url
			'date' => $self->{'time'},                               # date
			'tz'   => sb::Config->get->value('conf_timezone'),       # timezone
		);
		my $new = sb::Data->add('Amazon',%elem);
		sb::Data->update($new);
		$msg = $lang->string('parts_new_comp');
	}
	elsif ($cgi->value('update') eq '' and $cgi->value('action') ne '')
	{ # update info of selected items
		my @sels = split("\0",$cgi->value('sel'));
		my @amazon = sb::Data->load('Amazon','cond'=>{'id'=>\@sels});
		ACTION_SWITCH: {
			$_ = $cgi->value('regi_action');
			/^entry$/ && do { # create article with selected items
				my $newtext = '';
				foreach my $item (@amazon)
				{
					$newtext .= $item->formated_item;
				}
				$self->{'mode'} = 'new';
				return $self->_open_entry('newtext'=>$newtext);
			};
			/^del$/ && do { # delete selected items
				foreach my $item (@amazon)
				{
					$item->erase;
				}
				last ACTION_SWITCH;
			};
			/^stat(\d)$/ && do { # change status
				my $new = $1;
				foreach my $item (@amazon)
				{
					$item->stat($new);
				}
				last ACTION_SWITCH;
			};
			/^order$/ && do { # change order
				my $target = $amazon[0];
				@amazon = $self->change_order(
					'data'      => [ sb::Data->load('Amazon','sort'=>'order','order'=>1) ],
					'target'    => $target,
					'direction' => 0,
				);
				last ACTION_SWITCH;
			};
		};
		sb::Data->update(@amazon) if (@amazon);
		$msg = ($cgi->value('regi_action') eq 'del')
		     ? ($#amazon + 1) . $lang->string('parts_deleted')
		     : $lang->string('parts_editcomp');
	}
	else
	{ # update item info
		my @ids = split("\0",$cgi->value('sel_id'));
		my @amazon = sb::Data->load('Amazon','cond'=>{'id'=>\@ids});
		my $order = undef;
		foreach my $item (@amazon)
		{
			my $text = $cgi->value('aws_msg' . $item->id);
			$item->msg(sb::Text->entitize($text)) if ($cgi->value('update') ne '' and $self->check_permission('user'=>$item->pid));
			$order = $item if ($cgi->value('dn' . $item->id) ne '' or $cgi->value('up' . $item->id) ne '');
		}
		if ($order)
		{ # change the order
			@amazon = $self->change_order(
				'data'      => [ sb::Data->load('Amazon','sort'=>'order','order'=>1) ],
				'target'    => $order,
				'direction' => ($cgi->value('up' . $order->id) ne '') ? +1 : -1,
			);
		}
		sb::Data->update(@amazon) if (@amazon);
		$msg = $lang->string('parts_editcomp');
	}
	$self->build_list();
	return $self->_display_amazon_list('message'=>$msg);
}
sub _display_amazon_list
{
	my $self = shift;
	my %param = ( 'message' => '', @_ );
	my $cgi = sb::Interface->get;
	my $cms = sb::TemplateManager->new($self->load_template('file'=>TEMPLATE));
	if ($cgi->value('amazon_word') ne '')
	{ # search results
		my $aws = sb::Aws->new;
		my $genre = $cgi->value('amazon_genre');
		my $word = $cgi->value('amazon_word');
		my $page = ($cgi->value('page') eq '') ? 1 : int($cgi->value('page'));
		$page = int($cgi->value('now_page')) + 1 if ( $cgi->value('next') ne '' );
		$page = int($cgi->value('now_page')) - 1 if ( $cgi->value('prev') ne '' );
		my $result = $aws->get_data(
			'genre'    => ($genre eq 'ASIN') ? undef : $genre,
			'keyword'  => ($genre eq 'ASIN') ? undef : $word,
			'asin'     => ($genre eq 'ASIN') ? $word : undef,
			'page'     => $page,
			'locale'   => sb::Config->get->value('basic_aws_locale'),
			'id'       => $self->{'user'}->aws,
			'charcode' => sb::Language->get->charcode,
		);
		if ($result)
		{
			for (my $i=0;$i<$aws->count;$i++)
			{
				my $item = $result->[$i];
				$cms->num($i);
				foreach my $elem ('url','name','cat','cre','days','make','ism','imd','ilg','ava','lpr','opr')
				{
					my $tag = 'sb_aws_' . $elem;
					if ($elem eq 'cre' and ref($item->{'cre'}) eq 'ARRAY')
					{ # creators
						my @creators = @{$item->{'cre'}};
						my $firstone = ($#creators > 0) ? $creators[0] . SUFFIX_AUTHOR : $creators[0];
						$cms->tag($tag => sb::Text->entitize(join('&sb;',@creators)));
						$cms->tag($tag . '_one' => sb::Text->entitize($firstone));
					}
					else
					{
						$cms->tag($tag => sb::Text->entitize($item->{$elem}));
					}
					$cms->tag('sb_site_encoding',sb::Language->get->charset);
				}
				$cms->tag('sb_list_class'=>($i % 2) ? 'odd' : 'even');
				$cms->tag('sb_aws_image'=>($item->{'ism'} ne '') ? '<img src="' . $item->{'ism'} . '" />' : NO_IMAGE);
			}
			$cms->block('sb_amazon_result'=>$aws->count);
		}
		else
		{
			$cms->num(0);
			$cms->tag('sb_process_message'=>$aws->error);
			$cms->block('sb_amazon_message'=>1);
		}
		$cms->num(0);
		$cms->tag('page_now'=>$page);
		$cms->tag('sb_list_page'=>$self->display_pagelink(
				'mode'    => 'amazon',
				'column'  => LIST_COLUMN,
				'all'     => $aws->matched,
				'printed' => $aws->count,
				'num'     => DISPLAY_NUMBER,
				'start'   => 1,
				'end'     => $aws->page,
				'params'  => ['amazon_genre','amazon_word'],
			)
		);
		$cms->block('sb_amazon_search'=>1);
		$cms->block('sb_amazon_select'=>1);
		$cms->block('sb_amazon_mylist'=>0);
		$cms->block('sb_amazon_one'   =>0);
	}
	else
	{ # display existed items
		my $page = int($cgi->value('page'));
		$page = int($cgi->value('now_page')) + 1 if ( $cgi->value('next') ne '' );
		$page = int($cgi->value('now_page')) - 1 if ( $cgi->value('prev') ne '' );
		my @amazon = sb::Data->load('Amazon',
			'sort'  => 'order',
			'id'    => ( $cgi->value('aid') eq '' ) ? undef : $cgi->value('aid'),
			'num'   => DISPLAY_NUMBER,
			'bgn'   => $page * DISPLAY_NUMBER,
			'order' => 1,
		);
		my $mathed = sb::Data->matched;
		$cms->num(0);
		$cms->tag('page_now'=>$page);
		$cms->tag('sb_list_page'=>$self->display_pagelink(
				'mode'    => 'amazon',
				'column'  => MYLIST_COLUMN,
				'all'     => $mathed,
				'printed' => $#amazon + 1,
				'num'     => DISPLAY_NUMBER,
			)
		);
		$self->dispnum_selector(
			'cms'  => $cms,
			'now'  => DISPLAY_NUMBER,
		);
		$self->listmain(
			'template' => $cms,
			'block'    => 'sb_amazon_list',
			'objects'  => \@amazon,
			'tags'     => {
				'sb_aws_id'       => 'id',
				'sb_aws_image'    => \&_display_image,
				'sb_aws_name'     => \&_clip_for_name,
				'sb_aws_auth'     => \&_display_author,
				'sb_aws_msg'      => 'msg',
				'sb_aws_date'     => 'date',
				'sb_aws_dispstat' => \&_display_status,
				'sb_aws_stat'     => 'stat',
				'sb_aws_sel'      => \&_display_checkbox,
				'sb_aws_edit'     => \&_is_editable,
			},
		);
		if ($cgi->value('aid') ne '' and $amazon[0])
		{
			my $price = ($amazon[0]->opr ne '') ? $amazon[0]->opr : $amazon[0]->lpr;
			$price .= ' (' . $amazon[0]->lpr . ')' if ($amazon[0]->lpr ne '' and $amazon[0]->opr ne '');
			my $image = ($amazon[0]->ilg ne '') 
			          ? $amazon[0]->ilg 
			          : ($amazon[0]->imd ne '') ? $amazon[0]->imd : $amazon[0]->ism;
			$image = ($image ne '') ? '<img src="' . $image . '" />' : NO_IMAGE;
			$cms->num(0);
			$cms->tag('sb_aws_one_id'     => $amazon[0]->id);
			$cms->tag('sb_aws_one_name'   => $amazon[0]->name);
			$cms->tag('sb_aws_one_days'   => $amazon[0]->days);
			$cms->tag('sb_aws_one_make'   => $amazon[0]->make);
			$cms->tag('sb_aws_one_cre'    => sb::Text->format('text'=>$amazon[0]->cre,'form'=>1));
			$cms->tag('sb_aws_one_price'  => $price);
			$cms->tag('sb_aws_one_ava'    => $amazon[0]->ava);
			$cms->tag('sb_aws_one_image'  => $image);
			$cms->tag('sb_aws_one_msg'    => sb::Text->format('text'=>$amazon[0]->msg,'form'=>1));
			$cms->tag('sb_aws_order'      => sprintf(ORDER_COLUMN,DEFAULT_COLUMN,DEFAULT_COLUMN));
		}
		if ($cgi->value('aid') eq '')
		{
			my $end = int( $mathed / DISPLAY_NUMBER );
			$end-- if ( $mathed % DISPLAY_NUMBER == 0 and $mathed > 0);
			for (my $i=0;$i<@amazon;$i++)
			{ # marker for changing item order
				my $lcol = sprintf(ORDER_LEFT ,$amazon[$i]->id);
				my $rcol = sprintf(ORDER_RIGHT,$amazon[$i]->id);
				$lcol = DEFAULT_COLUMN if ($i == 0 and $page == 0);
				$rcol = DEFAULT_COLUMN if ($i == $#amazon and $page == $end );
				$cms->num($i);
				$cms->tag('sb_aws_order'=>sprintf(ORDER_COLUMN,$lcol,$rcol));
			}
		}
		$cms->block('sb_amazon_search'     =>0);
		$cms->block('sb_amazon_mylist'     =>1);
		$cms->block('sb_amazon_select_list'=>($cgi->value('aid') eq '') ? 1 : 0);
		$cms->block('sb_amazon_select'     =>($cgi->value('aid') eq '') ? 1 : 0);
		$cms->block('sb_amazon_one'        =>($cgi->value('aid') eq '') ? 0 : 1);
	}
	$cms->num(0);
	$cms->tag('sb_amazon_word'=>sb::Text->entitize($cgi->value('amazon_word')));
	my $selector  = '';
	my @aws_table = sb::Aws->get_genre(sb::Config->get->value('basic_aws_locale'));
	foreach my $genre (@aws_table)
	{
		my $word = sb::Language->get->string('aws_genre_' . $genre);
		$word = $genre if ($word eq 'aws_genre_' . $genre);
		$selector .= '<option value="' . $genre . '"';
		$selector .= ' selected="selected"' if ($genre eq $cgi->value('amazon_genre'));
		$selector .= '>' . $word . '</option>';
	}
	$cms->tag('sb_amazon_genre'=>$selector);
	if ($param{'message'} ne '')
	{ # process message
		$cms->num(0);
		$cms->tag('sb_process_message'=>$param{'message'});
		$cms->block('sb_amazon_message'=>1);
	}
	$self->common_template_parts($cms);
	return sb::Interface->get->head('type'=>'text/html') . $self->set_main($cms->output);
}
# ==================================================
# // private functions - for amazon list
# ==================================================
sub _display_image
{
	my $self = shift;
	my $obj  = shift;
	my $img = ($obj->ism ne '') 
	        ? '<img src="' . $obj->ism . '" alt="' . $obj->name . '" title="' . $obj->name . '" />' 
	        : NO_IMAGE;
	return $self->clip_text(
		'text' => $img,
		'base' => '?__mode=amazon&amp;aid=' . $obj->id,
		'user' => $obj->pid,
		'length' => length($img),
	);
}
sub _clip_for_name
{
	my $self = shift;
	my $obj  = shift;
	return $self->clip_text(
		'text'   => $obj->name,
		'length' => ITEM_LENGTH,
		'base'   => $obj->url,
		'target' => '_blank',
	);
}
sub _is_editable
{
	my $self = shift;
	my $obj  = shift;
	return ($self->check_permission('user'=>$obj->pid)) ? '' : 'disabled="disabled"';
}
sub _display_author
{
	my $self = shift;
	my $obj  = shift;
	my $pid  = ( defined($self->{'users'}->{$obj->pid}) ) ? $obj->pid : 0;
	return( $self->{'users'}->{$pid}->real );
}
sub _display_status
{
	my $self = shift;
	my $obj  = shift;
	return $self->list_status(
		'stat'   => $obj->stat,
		'string' => sb::Language->get->string('setup_aws_stat'),
	);
}
sub _display_checkbox
{
	my $self = shift;
	my $obj  = shift;
	return ( $self->check_permission('user'=>$obj->pid) and sb::Interface->get->value('aid') eq '' )
	? '<input type="checkbox" name="sel" value="' . $obj->id . '" onclick="switchList(this)" />'
	: DENIED_CHECK;
}
1;
__END__
