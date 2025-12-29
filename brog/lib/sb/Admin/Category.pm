# sb::Admin::Category - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Admin::Category;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.02';
# 0.02 [2007/02/06] changed @ISA, _display_category_list, and _update_category to handle new description
# 0.01 [2006/11/09] changed _display_category_list / changed _update_category to check index directory
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
use sb::Admin::Entry ();
@ISA = qw( sb::Admin::Entry );
# ==================================================
# // declaration for constant value
# ==================================================
sub TEMPLATE       (){ 'category.html' };
sub LIST_COLUMN    (){ 8 };
sub DEFAULT_COLUMN (){ '-' };
sub ORDER_LEFT     (){ '<input type="submit" name="up%d" value="&#9650;" class="updown" />' };
sub ORDER_RIGHT    (){ '<input type="submit" name="dn%d" value="&#9660;" class="updown" />' };
sub ORDER_COLUMN   (){ '%s</td><td>%s' };
sub NAVI_ARROW     (){ ' &gt; ' };
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
		? $self->_update_category(@_) 
		: $self->_display_category_list(@_);
}
# ==================================================
# // private functions - main routine
# ==================================================
sub _update_category
{
	my $self = shift;
	my %param = ( 'message' => '', @_ );
	my $cgi = sb::Interface->get;
	my $lang = sb::Language->get;
	my $msg  = '';
	my $main = ( $cgi->value('cid') ne '' ) 
		? sb::Data->load('Category','id'=>$cgi->value('cid')) 
		: undef;
	$self->{'cat'} = { sb::Data->load_as_hash('Category') };
	if ($cgi->value('__regi') eq 'add')
	{ # add new category
		if ($cgi->value('cat_name') ne '')
		{ # category name is required
			$main = $self->create_category(
				'name' => sb::Text->entitize($cgi->value('cat_name')),
				'main' => $cgi->value('cat_main'),
				'sub'  => ($cgi->value('cat_main') ne '') ? 1 : undef,
				'text' => $cgi->value('cat_text'),
			);
			$msg = $lang->string('parts_new_comp');
		}
		else
		{
			return $self->process_message($lang->string('error_no_cat'));
		}
	}
	elsif ($cgi->value('__regi') eq 'update')
	{ # modify category
		my @cats = sb::Data->load('Category', # load indicated categories
			'cond'  => {'id'=>[ split("\0",$cgi->value('sel_id')) ]},
			'order' => 1,
			'sort'  => 'order'
		);
		if ( $cgi->value('del') ne '' )
		{ # deleting
			my @selected = split("\0",$cgi->value('sel'));
			my @dels = ();
			foreach (@cats)
			{
				my $id = $_->id;
				if ( grep(/^\Q$id\E$/,@selected) )
				{
					push(@dels,$_);
					push(@dels,$self->_get_subs($_)) if ($_->sub ne '');
				}
			}
			foreach (@dels)
			{
				$_->erase;
			}
			sb::Data->update(@dels) if (@dels);
			$msg = ($#dels + 1) . $lang->string('parts_deleted');
		}
		else
		{ # renaming or changing order
			my $order = undef;
			foreach (@cats)
			{
				my $name = $cgi->value('cat_name' . $_->id);
				$_->name(sb::Text->entitize($name)) if ($name ne '' and $cgi->value('update') ne '');
				$order = $_ if ($cgi->value('dn' . $_->id) ne '' or $cgi->value('up' . $_->id) ne '');
			}
			if ($order)
			{ # changing order
				@cats = $self->change_order(
					'data'      => \@cats,
					'target'    => $order,
					'direction' => ($cgi->value('up' . $order->id) ne '') ? +1 : -1,
				);
			}
			$msg = $lang->string('parts_editcomp');
		}
		sb::Data->update(@cats) if (@cats and $cgi->value('del') eq '');
		if ($main)
		{ # modifing sub-category
			my @subs = ();
			foreach (sort { $b->order <=> $a->order } @cats)
			{
				next if ($_->erased);
				push(@subs,$_->id);
			}
			$main->sub(join(',',@subs) . ',');
			sb::Data->update($main);
		}
	}
	elsif ( $cgi->value('cid') ne '' )
	{ # modify details
		return $self->process_message($lang->string('error_no_cat')) if (!$main); # no category
		if ( $cgi->value('detail') ne '' )
		{ # we have the category to update
			$main->name(sb::Text->entitize($cgi->value('cat_name'))) if ($cgi->value('cat_name') ne '');
			$main->text($cgi->value('cat_text'));
			$main->url($cgi->value('cat_tb'));
			$main->temp($cgi->value('cat_temp'));
			$main->idx($cgi->value('cat_index'));
			$main->dir($cgi->value('cat_dir')) if ($cgi->value('cat_dir') ne '');
			my $disp = $cgi->value('cat_disptop') . ':';
			$disp .= $cgi->value('cat_displist') . ':';
			$disp .= ($cgi->value('cat_displine') eq 'on') ? '0:' : '1:';
			$disp .= $cgi->value('cat_dispsum') . ':';
			$main->disp($disp);
			if ($main->idx)
			{
				my $index_warning = '';
				foreach my $chk_cat ( values(%{$self->{'cat'}}) )
				{
					next if ($chk_cat->id == $main->id);
					next if (!$chk_cat->idx);
					next if ($chk_cat->dir ne $main->dir);
					$index_warning = $chk_cat->fullname($self->{'cat'});
					last;
				}
				$msg = sprintf($lang->string('error_dup_catidx'),$index_warning) if ($index_warning);
			}
			if ($cgi->value('cat_main') ne $main->main)
			{ # update parent
				my $flag = undef;
				my $old = ($main->main ne '') 
				        ? $self->{'cat'}->{$main->main} 
				        : undef;
				my $new = ($cgi->value('cat_main') ne '') 
				        ? $self->{'cat'}->{$cgi->value('cat_main')} 
				        : undef;
				foreach my $chk_cat ( values(%{$self->{'cat'}}) )
				{ # checking name whether the name is duplicated or not
					next if ($chk_cat->name ne $main->name);
					$flag = 1 if ($new and $chk_cat->main eq $cgi->value('cat_main')); # the same sub-category
					$flag = 1 if (!$new and $chk_cat->main eq ''); # the same parent-category
					last if ($flag);
				}
				if (!$flag)
				{ # not duplicated
					$main->main($cgi->value('cat_main'));
					if ($new)
					{ # needs update of parent category as well
						$new->add_sub($main->id);
						sb::Data->update($new);
					}
					if ($old)
					{
						$old->remove_sub($main->id);
						sb::Data->update($old);
					}
				}
				else
				{
					$msg = $lang->string('error_dup_cat');
				}
			}
		}
		elsif ( $cgi->value('del') ne '' )
		{ # delete indicated category
			my $parent = ($main->main ne '') ? $self->{'cat'}->{$main->main} : undef;
			my @dels = ( $main );
			push(@dels,$self->_get_subs($main)) if ($main->sub ne '');
			foreach (@dels)
			{
				$_->erase;
			}
			if ($parent)
			{
				$parent->remove_sub($main->id);
				sb::Data->update($parent);
			}
			sb::Data->update(@dels);
			return $self->process_message(($#dels + 1) . $lang->string('parts_deleted'));
		}
		if ($main)
		{
			sb::Data->update($main);
			$msg .= $lang->string('parts_editcomp');
		}
	}
	else
	{
		die($lang->string('error_unknown') . "\n");
	}
	$self->build_list('category_list');
	return $self->_display_category_list('message'=>$msg,'id'=>($main) ? $main->id : undef);
}
sub _display_category_list
{
	my $self = shift;
	my %param = (
		'message' => '',
		'id'      => undef,
		@_
	);
	my $cgi = sb::Interface->get;
	my $cms = sb::TemplateManager->new($self->load_template('file'=>TEMPLATE));
	my @cats = ();
	$self->{'cat'} = { sb::Data->load_as_hash('Category') };
	$self->{'cnt'} = $self->_count_entry;
	$self->common_template_parts($cms);
	if ($cgi->value('__type') ne 'tree')
	{ # edit mode
		$param{'id'} = $cgi->value('cid') if ($cgi->value('cid') ne '');
		if ($param{'id'} ne '') {
			if ($self->{'cat'}->{$param{'id'}})
			{
				foreach my $cat ( split(',',$self->{'cat'}->{$param{'id'}}->sub) )
				{
					next if ($cat eq '');
					next if (!$self->{'cat'}->{$cat});
					push(@cats,$self->{'cat'}->{$cat});
				}
			}
			else
			{
				return $self->process_message(sb::Language->get->string('error_no_cat'));
			}
		}
		else
		{
			foreach my $cat ( sort { $b->order <=> $a->order } values(%{$self->{'cat'}}) )
			{
				next if ($cat->main ne '');
				push(@cats,$cat);
			}
		}
		$cms->num(0);
		$self->listmain(
			'template' => $cms,
			'block'    => 'sb_category_list',
			'objects'  => \@cats,
			'tags'     => {
				'sb_catlist_id'   => 'id',
				'sb_catlist_name' => \&_display_name,
				'sb_catlist_num'  => sub { int($self->{'cnt'}->{$_[1]->id}) },
				'sb_catlist_sub'  => \&_display_subcat_num,
				'sb_catlist_del'  => \&_display_checkbox,
				'sb_site_cgi'     => sub { $self->get_script_path },
			},
		);
		for (my $i=0;$i<@cats;$i++)
		{ # for chaging order
			my $lcol = sprintf(ORDER_LEFT ,$cats[$i]->id);
			my $rcol = sprintf(ORDER_RIGHT,$cats[$i]->id);
			$lcol = DEFAULT_COLUMN if ($i == 0);
			$rcol = DEFAULT_COLUMN if ($i == $#cats);
			$cms->num($i);
			$cms->tag('sb_catlist_order'=>sprintf(ORDER_COLUMN,$lcol,$rcol));
		}
		if ( $param{'id'} ne '' and $self->{'cat'}->{$param{'id'}} )
		{
			my $main = $self->{'cat'}->{$param{'id'}};
			$cms->num(0);
			$cms->tag('sb_cat_id'=>$main->id);
			$cms->tag('sb_cat_name'=>$main->name);
			$cms->tag('sb_cat_text'=>sb::Text->entitize($main->text));
			$cms->tag('sb_cat_tb'=>$main->url);
			foreach my $key ('top','list','sum')
			{
				$self->select_option(
					'cms'      => $cms,
					'tag'      => 'sb_cat_disp' . $key . '_',
					'selected' => $main->get_option($key),
				);
			}
			$cms->tag('sb_cat_displine'=>'checked="checked"') if (!$main->get_option('line'));
			$self->template_selector(
				'cms' => $cms,
				'tag' => 'sb_cat_temp',
				'now' => ($main->temp == -1) ? undef : $main->temp,
			);
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
			
			# if (sb::Config->get->value('conf_entry_archive') ne 'None')
			{ # settings for stored directory and category index
				my @dirs = sort { $a cmp $b } sb::Config->get->writable_dir(sb::Config->get->value('conf_dir_log'));
				my $selector = '';
				foreach my $dir (@dirs)
				{ # directory setting
					$selector .= '<option value="' . $dir . '"';
					$selector .= ' selected="selected"' if ($main->dir eq $dir);
					$selector .= '>' . $dir . '</option>';
				}
				$cms->num(0);
				$cms->tag('sb_cat_dir'=>$selector);
				$cms->tag('sb_cat_index_' . $main->idx=>'selected="selected"') if ($main->idx);
				$cms->block('sb_category_dir'=>1);
				$cms->block('sb_category_index'=>1);
			} # end of settings for stored directory and category index
			my $navi = $self->_category_navigator(
				'id'  => $main->id,
				'tag' => '<a href="' . $self->get_script_path . '?__mode=category&amp;cid=%d">%s</a>',
				'now' => $main->id,
			);
			$navi .= ' (<a href="' . $self->get_script_path . '?__mode=list&amp;dispcat=';
			$navi .= $main->id . '">' . int($self->{'cnt'}->{$main->id}) . '</a>)';
			$cms->num(0);
			$cms->tag('sb_cat_navi'=>$navi);
			$cms->tag('sb_cat_selector'=>
				$self->category_selector(
					'cat'    => [ sort { $b->order <=> $a->order } values(%{$self->{'cat'}}) ],
					'now'    => $main->main,
					'except' => $main->id,
				)
			);
		}
		else
		{
			$cms->num(0);
			$cms->tag('sb_cat_selector'=>
				$self->category_selector('cat' => [ sort { $b->order <=> $a->order } values(%{$self->{'cat'}}) ])
			);
		}
		$cms->num(0);
		$cms->tag('sb_submenu_category_basic'=>' class="current"');
		$cms->block('sb_category_select'=>($param{'id'} eq '') ? 1 : 0);
		$cms->block('sb_category_one'   =>($param{'id'} eq '') ? 0 : 1);
		$cms->block('sb_category_basic' =>1);
		$cms->block('sb_category_tree'  =>0);
	}
	else
	{ # tree mode
		$cms->num(0);
		$cms->tag('sb_category_tree'=>
			$self->_category_tree(
				'cat'  => [ sort { $b->order <=> $a->order } values(%{$self->{'cat'}}) ],
				'num'  => $self->{'cnt'},
				'path' => $self->get_script_path . '?__mode=category&amp;cid=',
			)
		);
		$cms->tag('sb_submenu_category_tree'=>' class="current"');
		$cms->block('sb_category_select'=>0);
		$cms->block('sb_category_one'   =>0);
		$cms->block('sb_category_basic' =>0);
		$cms->block('sb_category_tree'  =>1);
	}
	if ($param{'message'} ne '')
	{ # process message
		$cms->num(0);
		$cms->tag('sb_process_message'=>$param{'message'});
		$cms->block('sb_category_message'=>1);
	}
	return sb::Interface->get->head('type'=>'text/html') . $self->set_main($cms->output);
}
# ==================================================
# // private functions - for category list
# ==================================================
sub _get_subs
{ # get sub-categories recursively
	my $self = shift;
	my $cat  = shift;
	my @subs = split(',',$cat->sub);
	my @objs = ();
	foreach (@subs)
	{
		my $obj = $self->{'cat'}->{$_};
		if ($obj)
		{
			push(@objs,$obj) ;
			push(@objs,$self->_get_subs($obj)) if ($obj->sub ne '');
		}
	}
	return @objs;
}
sub _category_tree
{ # category tree
	my $self  = shift;
	my %param = (
		'cat'    => [],
		'branch' => undef,   
		'num'    => {},
		'path'   => undef,
		'class'  => -1,
		@_
	);
	my $list = '';
	my $num = $param{'class'};
	foreach my $cat ( @{$param{'cat'}} )
	{
		next if (!defined($param{'branch'}) and $cat->main ne '');
		next if ( defined($param{'branch'}) and $cat->main ne $param{'branch'});
		my $dir = (sb::Config->get->value('conf_entry_archive') ne 'Individual') 
			? undef
			: ($cat->dir ne '') ? $cat->dir : sb::Config->get->value('conf_dir_log');
		$num++;
		$list .= ($num % 2) ? '<li class="odd">' : '<li class="even">';
		$list .= '<span class="dir">' . $dir . '</span>' if ($dir);
		$list .= '<a href="' . $param{'path'} . $cat->id . '">' . $cat->name . '</a>';
		$list .= ' (' . int($param{'num'}->{$cat->id}) . ')';
		if ($cat->sub ne '')
		{
			$list .= "\n" . '<ul>';
			$list .= $self->_category_tree(
				'cat'    => $param{'cat'},
				'branch' => $cat->id,
				'num'    => $param{'num'},
				'path'   => $param{'path'},
				'class'  => $num,
			);
			$list .= '</ul>';
		}
		$list .= '</li>' . "\n";
	}
	return($list);
}
sub _category_navigator
{
	my $self = shift;
	my %param = (
		'id'  => undef,
		'tag' => '',
		'now' => undef,
		@_
	);
	return( undef ) if (!defined($param{'id'}));
	return( undef ) if (!$self->{'cat'}->{$param{'id'}});
	if ( $self->{'cat'}->{$param{'id'}}->main eq '')
	{
		return ($param{'now'} eq $param{'id'})
			? $self->{'cat'}->{$param{'id'}}->name
			: sprintf($param{'tag'},$param{'id'},$self->{'cat'}->{$param{'id'}}->name);
	}
	else
	{
		my $navi = $self->_category_navigator(
			'id'  => $self->{'cat'}->{$param{'id'}}->main,
			'tag' => $param{'tag'},
			'now' => $param{'now'},
		);
		$navi .= NAVI_ARROW if ($navi);
		return ($param{'now'} eq $param{'id'})
			? $navi . $self->{'cat'}->{$param{'id'}}->name
			: $navi . sprintf($param{'tag'},$param{'id'},$self->{'cat'}->{$param{'id'}}->name);
	}
}
sub _display_name
{
	my $self = shift;
	my $obj  = shift;
	return '<input type="text" name="cat_name' . $obj->id . '" value="' . $obj->name . '" size="24" style="width:240px;" class="text" />';
}
sub _display_subcat_num
{
	my $self = shift;
	my $obj  = shift;
	my $sub  = $obj->sub;
	return int( $sub =~ s/,/,/g );
}
sub _display_checkbox
{
	my $self = shift;
	my $obj  = shift;
	return '<input type="checkbox" name="sel" value="' . $obj->id . '" onclick="switchList(this)" />';
}
sub _count_entry
{
	my $self = shift;
	my %count = ();
	my @array = sb::Data->load('Entry');
	for (my $i=0;$i<@array;$i++)
	{
		next if ($array[$i]->cat eq '');
		my $cat = $self->{'cat'}->{$array[$i]->cat};
		next if (!$cat);
		$count{$cat->id}++;
		if ($array[$i]->add ne '')
		{ # count additional category as well
			foreach ( split(',',$array[$i]->add) )
			{
				next if ($_ eq '');
				$count{$_}++;
			}
		}
	}
	return \%count;
}
1;
__END__
