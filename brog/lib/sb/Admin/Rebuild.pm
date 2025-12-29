# sb::Admin::Rebuild - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Admin::Rebuild;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.09';
# 0.09 [2006/02/16] changed _do_rebuild to display message correctly
# 0.08 [2006/02/03] changed _get_directories to check parent dir correctly
# 0.07 [2006/02/03] changed _open_rebuild_option to enable rebuild menu for normal user
# 0.06 [2005/10/22] changed _do_rebuild to change message for rebuilding partly
# 0.05 [2005/07/22] changed _build_files to build files correctly
# 0.04 [2005/07/19] changed _check_extra
# 0.03 [2005/07/18] changed _open_rebuild_option to add extra rebuild option
# 0.02 [2005/07/16] changed _buikd_files to change the order of building files
# 0.01 [2005/07/08] changed _build_files to create a js for cookie
# 0.00 [2005/04/09] generate

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Build ();
use sb::Config ();
use sb::Interface ();
use sb::App::Admin ();
@ISA = qw( sb::App::Admin );
# ==================================================
# // declaration for constant value
# ==================================================
sub TEMPLATE      (){ 'rebuild.html' };
sub DEFAULT_TYPE  (){ 'main' };
sub REBUILD_LEVEL (){ 1 };
sub SHOW_DETAIL   (){ '<a href="#" onclick="return toggleVisible(\'%s\',null,null);">%s</a>' };
sub EXTRA_SCRIPT  (){ "<script type=\"text/javascript\">\n<!--\ninitRebuildField();\n// -->\n</script>" };
# ==================================================
# // public functions - callback
# ==================================================
sub callback { # callbacks
	my $self = shift;
	return ( $self->{'regi'} ) 
		? $self->_do_rebuild(@_)
		: $self->_open_rebuild_option(@_);
}
# ==================================================
# // private functions - main routine
# ==================================================
sub _do_rebuild {
	my $self = shift;
	my %param = ( 'message' => '', @_ );
	my $cgi = sb::Interface->get;
	my $lang = sb::Language->get;
	my $user = $self->{'user'};
	my $msg = '';
	if (  $cgi->value('__type') ne DEFAULT_TYPE and !$self->check_permission('level'=>REBUILD_LEVEL)) {
		return $self->_open_rebuild_option('message'=>$lang->string('error_not_allow'));
	}
	SWITCH_TYPE: {
		$_ = $cgi->value('__type');
		/^main$/ && do {
			$self->{'cat'} = { sb::Data->load_as_hash('Category') };
			my $option = $cgi->value('rebuild_option');
			$option = 'index' if ($option eq '' or sb::Config->get->value('conf_entry_archive') eq 'None');
			$self->_build_files($option);
			$msg .= '[#' . ($option + 1) . '] ' if ($option =~ /^\d+$/);
			$msg .= $lang->string('parts_buildcmp');
			last SWITCH_TYPE;
		};
		/^cleanup$/ && do {
			my $base = sb::Config->get->value('conf_dir_base');
			my @dirs = $self->_get_directories(
				'target' => 'log',
				'filter' => '.+' . sb::Config->get->value('basic_suffix'),
			);
			my $num = 0;
			foreach my $check ( @dirs ) {
				my $dir = $base . $check->{'dir'};
				foreach my $file ( @{$check->{'files'}} ) {
					$num++ if (unlink($dir . $file));
				}
			}
			$msg = $num . $lang->string('parts_deleted');
			last SWITCH_TYPE;
		};
		/^dir$/ && do {
			my $dir = sb::Config->get->value('conf_dir_base');
			if ($cgi->value('create') ne '' and $cgi->value('new_dir') =~ /[a-zA-Z0-9_\-]+/) {
				$dir .= $cgi->value('parent_dir') if ($cgi->value('parent_dir') ne '');
				$dir .= $cgi->value('new_dir');
				if (!-e $dir) {
					eval{ umask(0) };
					mkdir($dir,sb::Config->get->value('basic_dir_attr'));
					$msg = (-e $dir) ? $lang->string('parts_new_comp') : $lang->string('error_failtomake');
				} else {
					$msg = $lang->string('error_dup_dir');
				}
			} elsif ($cgi->value('delete') ne '' and $cgi->value('delete_dir') ne '') {
				$dir .= $cgi->value('delete_dir');
				rmdir($dir) if (-e $dir);
				$msg = (!-e $dir) ? '1' . $lang->string('parts_deleted') : $lang->string('error_failtodel');
			}
			last SWITCH_TYPE;
		};
	}
	return $self->_open_rebuild_option('message'=>$msg);
}
sub _open_rebuild_option {
	my $self = shift;
	my %param = ( 'message' => '', @_ );
	my $cgi = sb::Interface->get;
	my $cms = sb::TemplateManager->new($self->load_template('file'=>TEMPLATE));
	my $type = ( $cgi->value('__type') ne '' ) ? $cgi->value('__type') : DEFAULT_TYPE;
	print sb::Interface->get->head('type'=>'text/html');
	if ($type ne DEFAULT_TYPE and !$self->check_permission('level'=>REBUILD_LEVEL)) {
		$type = DEFAULT_TYPE;
		$param{'message'} = sb::Language->get->string('error_not_allow') if (!$param{'message'});
	}
	SWITCH_TYPE: {
		$_ = $type;
		/^main$/ && do { # display rebuild options
			my @entries = sb::Data->load('Entry','cond'=>{'stat'=>[1,2]});
			my $type = sb::Config->get->value('conf_entry_archive');
			my $num = sb::Data->matched;
			{ # for normal build
				my $max = sb::Config->get->value('basic_buildnum');
				my $selector = '';
				my $build_sel = int($num / $max) + 1;
				$build_sel-- if ($num % $max == 0 and $num > 0);
				for (my $i=0;$i<$build_sel;$i++) {
					$selector .= '<option value="' . $i . '">';
					$selector .= sprintf(
						sb::Language->get->string('parts_build_op'),
						($i + 1),
						($i * $max) + 1,
						($i + 1) * $max
					);
					$selector .= '</option>';
				}
				$cms->num(0);
				$cms->tag('sb_rebuild_options'=>$selector);
				$cms->block('sb_rebuild_option'=>1) if ($type ne 'None');
			}
			{ # for ajax build
				if ($type eq 'Individual') {
					my $max = sb::Config->get->value('basic_build_ajax');
					my $check = int($num / $max) + 1;
					$check-- if ($num % $max == 0 and $num > 0);
					$num = $check;
				} elsif ($type eq 'Monthly') {
					my %check = ();
					for (my $i=0;$i<@entries;$i++) {
						my $month = sb::Time->format(
							'time'=>$entries[$i]->date,
							'form'=>'%Year%%Mon%',
							'zone'=>$entries[$i]->tz
						);
						$check{$month} = $month if ( !defined($check{$month}) );
					}
					$num = keys(%check);
				}
				$cms->num(0);
				$cms->tag('sb_rebuild_max'=>$num);
				$self->_check_extra($cms) if ($type ne 'None');
			}
			last SWITCH_TYPE;
		};
		/^cleanup$|^dir$/ && do { # display directory information
			my @dirs = $self->_get_directories(
				'target' => ($type eq 'cleanup') ? 'log' : 'both',
				'filter' => ($type eq 'cleanup') ? '.+' . sb::Config->get->value('basic_suffix') : undef,
			);
			$cms->num(0);
			$cms->tag('sb_directory_tree'=>
				$self->_directory_tree(
					'dir'       => \@dirs,
					'show_file' => ($type eq 'cleanup') ? 1 : undef,
				)
			);
			if ($type eq 'dir') {
				my %sel = ('all'=>undef,'del'=>undef);
				foreach my $dir ( @dirs ) {
					my $option = '<option value="' . $dir->{'dir'} . '">' . $dir->{'dir'} . '</option>' . "\n";
					$sel{'all'} .= $option;
					$sel{'del'} .= $option if ($dir->{'num'} == 0 and !$dir->{'sub'});
				}
				$cms->tag('sb_all_directory'=>$sel{'all'});
				$cms->tag('sb_deletable_directory'=>$sel{'del'});
			}
			last SWITCH_TYPE;
		};
	}
	$self->common_template_parts($cms);
	$cms->tag('sb_rebuild_menu_' . $type => 'class="current"');
	$cms->block('sb_rebuild_' . $type => 1);
	$cms->block('sb_rebuild_typelist' => 1) if ($self->{'user'}->stat <= REBUILD_LEVEL);
	if ($param{'message'} ne '') { # display message
		$cms->num(0);
		$cms->tag('sb_process_message'=>$param{'message'});
		$cms->block('sb_rebuild_message'=>1);
	}
	return $self->set_main($cms->output);
}
# ==================================================
# // private functions - for rebuild screen
# ==================================================
sub _build_files { # rebuild files
	my $self = shift;
	my $option  = shift;
	my $max     = sb::Config->get->value('basic_buildnum');
	my $type    = sb::Config->get->value('conf_entry_archive');
	my $builder = sb::Build->new(
		'time'      => $self->{'time'},
		'user'      => $self->{'users'},
		'cat'       => $self->{'cat'},
		'sortedcat' => [ sort { $b->order <=> $a->order } values(%{$self->{'cat'}}) ],
		'blog'      => sb::Data->load('Weblog','id'=>0),
	);
	$builder->set_entryinfo;
	if ($option ne 'index') {
		my @entries = sb::Data->load('Entry',
			'cond'   => {'stat'=>[1,2]},
			'sort'   => 'date',
			'order'  => 1,
			'num'    => ($option =~ /^\d+$/) ? $max + 2 : -1,
			'bgn'    => ($option =~ /^\d+$/ and $option > 0) ? ($option * $max - 1) : 0,
			'detail' => 'on',
		);
		if ($type eq 'Individual') {
			my $bgn = ($option =~ /^\d+$/ and $option > 0) ? 1 : 0;
			my $end = @entries;
			if ($option =~ /^\d+$/) {
				$end = $max if ($option == 0);
				$end = $max + 1 if ($end > $max + 1);
			}
			for (my $i=$bgn;$i<$end;$i++) {
				my $nxt = ($i > 0)         ? $entries[$i - 1] : undef;
				my $prv = ($i < $#entries) ? $entries[$i + 1] : undef;
				$builder->build_entry($entries[$i],'prev'=>$prv,'next'=>$nxt);
			}
		} elsif ($type eq 'Monthly') {
			my @months = ();
			foreach my $entry ( @entries ) {
				my $month = sb::Time->format(
					'time'=>$entry->date,
					'form'=>'%Year%%Mon%',
					'zone'=>$entry->tz,
				);
				push(@months,$month);
			}
			{ # remove duplicated month
				my %cnt = ();
				@months = grep(!$cnt{$_}++, @months);
			}
			foreach my $month ( @months ) {
				$builder->build_monthly_archive( $month );
			}
		}
	}
	if ($option eq 'index' or $option eq 'all') {
		foreach my $cat ( values(%{$self->{'cat'}}) ) { # category indexes
			next if (!$cat->idx);
			next if ($cat->dir eq '');
			$builder->build_category_index($cat->id);
		}
		$builder->set_latest_entries;
		$builder->build_top_page;
		$builder->build_feedfile('all');
		$builder->build_javascript('all') if ($type eq 'Individual');
		$builder->build_css;
		$builder->build_cookie_js('force_to_create');
	}
}
sub _get_directories {
	my $self = shift;
	my %param = (
		'target' => 'both', # 'log','img' or 'both'
		'filter' => undef,
		@_
	);
	my @dirs = ();
	my @tree = ();
	my $num  = 0;
	my $type = $param{'target'};
	my $cond = $param{'filter'};
	my $conf = sb::Config->get;
	push(@dirs,$conf->writable_dir($conf->value('conf_dir_log'))) if ($type eq 'both' or $type eq 'log');
	push(@dirs,$conf->writable_dir($conf->value('conf_dir_img'))) if ($type eq 'both' or $type eq 'img');
	{ # remove duplicated directories
		my %cnt = ();
		@dirs = grep(!$cnt{$_}++, @dirs);
	}
	@dirs = sort { $a cmp $b } @dirs;
	foreach my $check (@dirs) {
		my $dir = $conf->value('conf_dir_base') . $check;
		my @sep = split('/',$check);
		my $cur = {
			'id'     => $num,
			'name'   => $sep[$#sep],
			'dir'    => $check,
			'parent' => '',
			'num'    => 0,
			'files'  => [],
			'sub'    => undef,
			'root'   => $sep[0],
			'depth'  => $#sep,
		};
		$#sep--;
		$cur->{'parent'} = $sep[$#sep] if ($#sep >= 0);
		$tree[$#tree]->{'sub'} = 1 if ($#tree >= 0 and $tree[$#tree]->{'dir'} eq join('/',@sep) . '/');
		opendir(CHECKDIR, $dir);
		my @filelist = readdir(CHECKDIR);
		closedir(CHECKDIR);
		foreach my $file (@filelist) {
			next if (-d  $dir . $file);
			next if (!-r $dir . $file);
			next if (!-w $dir . $file);
			next if ($cond and $file !~ /$cond/);
			push(@{$cur->{'files'}},$file);
			$cur->{'num'}++;
		}
		$num++;
		push(@tree,$cur);
	}
	return( @tree );
}
sub _directory_tree {
	my $self  = shift;
	my %param = (
		'dir'       => [],
		'branch'    => undef,   
		'class'     => -1,
		'show_file' => undef,
		'depth'     => 0,
		'root'      => undef,
		@_
	);
	my $list = '';
	my $num = $param{'class'};
	foreach my $dir ( @{$param{'dir'}} ) {
		next if (!defined($param{'branch'}) and $dir->{'parent'} ne '');
		if ( defined($param{'branch'}) ) { # for sub directories
			next if ($dir->{'parent'} ne $param{'branch'});     # check parent directory
			next if ($dir->{'depth'} != ($param{'depth'} + 1)); # check depth of directory
			next if ($dir->{'root'} ne $param{'root'});         # check root directory
		}
		$num++;
		$list .= ($num % 2) ? '<li class="odd">' : '<li class="even">';
		$list .= '<span class="dir">';
		if ($param{'show_file'} and @{$dir->{'files'}}) {
			my $label = sb::Language->get->string('parts_showfile');
			$list .= sprintf(SHOW_DETAIL,'dir' . $dir->{'id'},$label);
		}
		$list .= '(' . int($dir->{'num'}) . ')</span>';
		$list .= $dir->{'name'};
		if ($param{'show_file'} and @{$dir->{'files'}}) {
			$list .= "\n" . '<ol id="dir' . $dir->{'id'} . '" style="display:none;">';
			foreach my $file ( @{$dir->{'files'}} ) {
				$list .= '<li>' . $file . '</li>' . "\n";
			}
			$list .= '</ol>';
		}
		if ($dir->{'sub'}) {
			$list .= "\n" . '<ul>';
			$list .= $self->_directory_tree(
				'dir'       => $param{'dir'},
				'branch'    => $dir->{'name'},
				'class'     => $num,
				'show_file' => $param{'show_file'},
				'depth'     => $dir->{'depth'},
				'root'      => $dir->{'root'},
			);
			$list .= '</ul>';
		}
		$list .= '</li>' . "\n";
	}
	return($list);
}
sub _check_extra {
	my $self = shift;
	my $cms = shift;
	if (sb::Config->get->value('basic_use_ajax')) {
		$cms->num(0);
		$cms->tag('sb_extra_rebuild'=>EXTRA_SCRIPT);
	}
}
1;
__END__
