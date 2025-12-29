# sb::Plugin::Convert - Plugin for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

# 0.07 [2007/07/05] changed _convert_data_from_xml to import filename correctly
# 0.06 [2007/07/04] merged Fuco's patch. Thx Fuco!
# 0.05 [2006/08/03] changed detail to point new site address
# 0.04 [2005/10/26] changed _export_data to fix the following bugs, thanks Fuco.
#                   - changed output charset to utf-8, exporting as xml.
#                   - changed order of articles, comments, and trackbacks.
#                   - optimized exporting routine.
#                   - added _export_body_text to output article text correctly.
# 0.03 [2005/10/23] for 2.03R
# 0.02 [2005/08/11] chnaged _parse_txt to parse text correctly, thanks Fuco.
# 0.01 [2005/06/08] chnaged _import_data to remove BOM for utf-8, thanks Fuco.

package sb::Plugin::Convert;
# ==================================================
# // initialization for plugin
# ==================================================
use sb::Plugin ();

sb::Plugin->register_plugin(
	'lang' => {
		'ja' => 'euc',
		'en' => 'ascii',
	},
	'text' => {
		'type'    => 'admin',
		'name'    => 'Convert Data',
		'text'    => 'UI for converting data',
		'author'  => 'takkyun',
		'detail'  => 'http://serenebach.net/',
		'version' => '0.07',
	},
	'file' => 'convert.txt',
	'data' => undef,
);

sb::Plugin->register_admin_module(
	'mode'   => 'convert',
	'level'  => 0,
	'module' => 'sb::Admin::Convert',
);

package sb::Admin::Convert;
# ==================================================
# // declaration for global variables
# ==================================================
use strict;
use vars qw( @ISA );
# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use XML::Parser::Lite ();
use sb::Language ();
use sb::Interface ();
use sb::Config ();
use sb::TemplateManager ();
use sb::Text ();
use sb::Time ();
use sb::Data ();
use sb::Content ();
use sb::Admin::List ();
@ISA = qw( sb::Admin::List );
# ==================================================
# // declaration for constant value
# ==================================================
sub TEMPLATE          (){ 'convert.html' };
sub DEFAULT_OUTPUT    (){ 'xml' };
sub DEFAULT_CODE      (){ 'utf8' };
sub DEFAULT_TYPE      (){ 'import' };
sub DEFAULT_USERNAME  (){ 'user' };
sub NAME_TAILSEED     (){ 1024 };
sub DATATYPE_XML      (){ 'xml' };
sub DATATYPE_TD2      (){ 'td2' };
sub DATATYPE_TXT      (){ 'txt' };
sub TEMPLATE_XML      (){ 'convert_simple.xml' };
sub TEMPLATE_TXT      (){ 'convert_mtlog.txt' };
sub EXPORT_STAT_CLOSE (){ 'Draft' };
sub EXPORT_STAT_OPEN  (){ 'Publish' };
sub EXPORT_XMLTIME    (){ '%Year%/%Mon%/%Day% %Hour%:%Min%:%Sec%' };
sub EXPORT_TXTTIME    (){ '%Mon%/%Day%/%Year% %Hour%:%Min%:%Sec%' };
sub EXPORT_XMLCHARSET (){ 'utf-8' };
sub EXPORT_XMLCODE    (){ 'utf8' };
# ==================================================
# // declaration for class member
# ==================================================
my %mImport = ();
# ==================================================
# // public functions - callback
# ==================================================
sub callback
{
	my $self = shift;
	return ( $self->{'regi'} ) 
		? $self->_check_import_option(@_)
		: $self->_open_convert_option(@_);
}
# ==================================================
# // private functions - main routine
# ==================================================
sub _check_import_option
{
	my $self = shift;
	my %param = ( 'message' => '', @_ );
	my $msg = '';
	my $cgi  = sb::Interface->get;
	my $lang = sb::Language->get;
	$self->{'flag'} = $cgi->value('import_user');
	$self->{'pass'} = $cgi->value('import_pass');
	$msg = $lang->string('error_no_data') if ($cgi->value('import_data') eq '');
	$msg = $lang->string('error_import_cond') if ($self->{'flag'} ne 'on' and $self->{'pass'} eq '');
	$msg = $lang->string('error_wrong_text') if ($self->{'pass'} ne '' and $self->{'pass'} !~ /^\w+$/);
	if ($msg eq '') {
		my $num = $self->_import_data($cgi->value('import_data'));
		$msg = $num . $lang->string('parts_import');
	}
	$lang->checkcode('',$lang->charcode); # to avoid greeking
	return $self->_open_convert_option('message'=>$msg);
}
sub _open_convert_option
{
	my $self = shift;
	my %param = ( 'message' => '', @_ );
	my $cgi = sb::Interface->get;
	my $cms = sb::TemplateManager->new(sb::Plugin->load_template('file'=>TEMPLATE));
	my $type = $cgi->value('__type') || DEFAULT_TYPE;
	if ( !defined($self->{'cat'}) )
	{ # make sure we get category data
		$self->{'cat'} = { sb::Data->load_as_hash('Category') };
	}
	my @cats = sort { $b->order <=> $a->order } values(%{$self->{'cat'}});
	if ($cgi->value('export') eq 'on')
	{
		my $format = $cgi->value('type') || DEFAULT_OUTPUT;
		my $output = $self->_export_data(
			'type' => $format,
			'cid'  => $cgi->value('cat'),
			'date' => $cgi->value('date'),
		);
		my $type = ($format eq 'txt') ? 'text/plain' : 'text/xml';
		my $set  = ($format eq 'txt') ? sb::Language->get->charset : EXPORT_XMLCHARSET;
		return ($output) 
			? sb::Interface->get->head('type'=>$type,'length'=>length($output),'charset'=>$set) . $output
			: $self->process_message(sb::Language->get->string('error_no_entry'));
	}
	else
	{
		$cms->num(0);
		SWITCH_TYPE: {
			$_ = $type;
			/^export$/ && do {
				$self->monthly_selector(
					'cms'  => $cms,
					'tag'  => 'sb_entry_date',
					'data' => 'Entry',
				);
				$cms->tag('sb_entry_cat'=>
					$self->category_selector(
						'cat'=>\@cats,
						'now'=>$cgi->value('dispcat')
					)
				);
				$cms->tag('type_xml'=>'selected="selected"') if ($cgi->value('convert_type') eq 'xml');
				$cms->tag('type_txt'=>'selected="selected"') if ($cgi->value('convert_type') eq 'txt');
				if ($cgi->value('reflect') ne '')
				{
					my $option = '';
					$option .= ($cgi->value('convert_type') eq 'txt') ? '&amp;type=txt' : '&amp;type=xml';
					$option .= '&amp;cat=' . $cgi->value('dispcat') if ($cgi->value('dispcat') ne '');
					$option .= '&amp;date=' . $cgi->value('dispdate') if ($cgi->value('dispdate') ne '');
					$cms->tag('sb_convert_option'=>$option);
					$cms->block('sb_do_export'=>1);
				}
				last SWITCH_TYPE;
			};
		}
		$cms->num(0);
		$cms->tag('sb_convert_menu_' . $type => 'class="current"');
		$cms->block('sb_convert_' . $type => 1);
		if ($param{'message'} ne '')
		{
			$cms->num(0);
			$cms->tag('sb_process_message'=>$param{'message'});
			$cms->block('sb_process_message'=>1);
		}
		$self->common_template_parts($cms);
		return sb::Interface->get->head('type'=>'text/html') . $self->set_main($cms->output);
	}
}
# ==================================================
# // private functions - for export
# ==================================================
sub _export_data
{
	my $self = shift;
	my %param = (
		'type' => DEFAULT_OUTPUT,
		'cid'  => undef,
		'date' => undef,
		@_
	);
	my $dir  = sb::Plugin->get_resource_dir;
	my $file = ($param{'type'} eq 'txt') ? TEMPLATE_TXT : TEMPLATE_XML;
	my %cond = ();
	if ($param{'date'} ne '')
	{
		$cond{'date'} = $self->create_date_condition($param{'date'});
		$cond{'__range'} = { 'date' => 'tz' };
	}
	if ($param{'cid'} ne '')
	{
		$cond{'cat'} = $param{'cid'};
		$cond{'__combo'} = { 'cat' => 'add' , 'add' => ',' . $param{'cid'} . ',' };
	}
	my @check = sb::Data->load('Entry',
		'sort'   => 'date',
		'cond'   => \%cond,
		'order'  => 0,
	);
	my @entries = ();
	for (my $i=0;$i<@check;$i++)
	{
		my $ent = sb::Data->load('Entry','id'=>$check[$i]->id);
		push(@entries,$ent) if ($ent);
	}
	if (@entries)
	{
		my $cms = sb::TemplateManager->new(sb::Plugin->load_template('file'=>$file,'dir'=>$dir));
		my %extend = (
			'entry' => {
				'export'    => ($param{'type'} eq 'txt') ? \&_export_txt : \&_export_xml,
				'body_text' => \&_export_body_text,
			},
		);
		$extend{'main'} = { '_main' => \&_export_common_parts } if ($param{'type'} eq 'xml');
		my $output = sb::Content->output($cms,
			'mode'      => 'ent',
			'time'      => $self->{'time'},
			'blog'      => sb::Data->load('Weblog','id'=>0),
			'user'      => $self->{'users'},
			'cat'       => $self->{'cat'},
			'sortedcat' => [sort { $b->order <=> $a->order } values(%{$self->{'cat'}})],
			'entryinfo' => {},
			'entry'     => \@entries,
			'entry_num' => $#entries + 1,
			'extend'    => \%extend,
		);
		my $lang = sb::Language->get;
		if ($param{'type'} eq 'xml' and $lang->charcode ne EXPORT_XMLCODE)
		{
			$lang->checkcode('',$lang->charcode);
			$output = $lang->convert($output,EXPORT_XMLCODE);
		}
		return $output;
	}
	else
	{
		return undef;
	}
}
sub _export_txt
{
	my $cms   = shift;
	my $entry = shift;
	my %var   = @_;
	$cms->tag('export_entry_status'=>($entry->stat == 0) ? EXPORT_STAT_CLOSE : EXPORT_STAT_OPEN);
	$cms->tag('export_entry_allowcomments'=>$entry->acm);
	$cms->tag('export_entry_allowpings'=>$entry->atb);
	$cms->tag('export_entry_format'=>$entry->form);
	$cms->tag('export_entry_date'=>
		sb::Time->format(
			'time' => $entry->date,
			'form' => EXPORT_TXTTIME,
			'zone' => $entry->tz,
			'lang' => 'en',
		)
	);
	my @comments = &_export_com_and_tb($entry->id,'Message');
	my $comment_field = '';
	foreach my $com (@comments)
	{
		my $date = sb::Time->format(
			'time'=>$com->date,
			'form'=>EXPORT_TXTTIME,
			'zone'=>$com->tz,
			'lang'=>'en',
		);
		$comment_field .= 'COMMENT:' . "\n";
		$comment_field .= 'AUTHOR: ' . $com->auth . "\n";
		$comment_field .= 'EMAIL: ' . $com->mail . "\n";
		$comment_field .= 'IP: ' . $com->host . "\n";
		$comment_field .= 'URL: ' . $com->url . "\n";
		$comment_field .= 'DATE: ' . $date . "\n";
		$comment_field .= $com->body . "\n";
		$comment_field .= '-----' . "\n";
	}
	$cms->tag('export_entry_comments'=>$comment_field);
	my @trackbacks = &_export_com_and_tb($entry->id,'Trackback');
	my $trackback_field = '';
	foreach my $tb (@trackbacks)
	{
		my $date = sb::Time->format(
			'time'=>$tb->date,
			'form'=>EXPORT_TXTTIME,
			'zone'=>$tb->tz,
			'lang'=>'en',
		);
		$trackback_field .= 'PING:' . "\n";
		$trackback_field .= 'TITLE: ' . $tb->subj . "\n";
		$trackback_field .= 'BLOG NAME: ' . $tb->name . "\n";
		$trackback_field .= 'URL: ' . $tb->url . "\n";
		$trackback_field .= 'IP: ' . $tb->host . "\n";
		$trackback_field .= 'DATE: ' . $date . "\n";
		$trackback_field .= $tb->body . "\n";
		$trackback_field .= '-----' . "\n";
	}
	$cms->tag('export_entry_pings'=>$trackback_field);
}
sub _export_xml
{
	my $cms   = shift;
	my $entry = shift;
	my %var   = @_;
	$cms->tag('export_entry_status'=>($entry->stat == 0) ? EXPORT_STAT_CLOSE : EXPORT_STAT_OPEN);
	$cms->tag('export_entry_allowcomments'=>$entry->acm);
	$cms->tag('export_entry_allowpings'=>$entry->atb);
	$cms->tag('export_entry_format'=>$entry->form);
	$cms->tag('export_entry_date'=>
		sb::Time->format(
			'time' => $entry->date,
			'form' => EXPORT_XMLTIME,
			'zone' => $entry->tz,
			'lang' => 'en',
		) . $entry->tz
	);
	$cms->tag('export_filename'=>$entry->file);
	my @comments = &_export_com_and_tb($entry->id,'Message');
	my $comment_field = '';
	foreach my $com (@comments)
	{
		my $date = sb::Time->format(
			'time'=>$com->date,
			'form'=>EXPORT_XMLTIME,
			'zone'=>$com->tz,
			'lang'=>'en',
		) . $com->tz;
		$comment_field .= '<comment>' . "\n" . '<title />' . "\n";
		$comment_field .= '<description><![CDATA[' . $com->body . ']]></description>' . "\n";
		$comment_field .= '<name>' . $com->auth . '</name>' . "\n";
		$comment_field .= '<email>' . $com->mail . '</email>' . "\n";
		$comment_field .= '<url>' . $com->url . '</url>' . "\n";
		$comment_field .= '<host>' . $com->host . '</host>' . "\n";
		$comment_field .= '<date>' . $date . '</date>' . "\n";
		$comment_field .= '</comment>' . "\n";
	}
	$cms->tag('export_entry_comments'=>$comment_field);
	my @trackbacks = &_export_com_and_tb($entry->id,'Trackback');
	my $trackback_field = '';
	foreach my $tb (@trackbacks)
	{
		my $date = sb::Time->format(
			'time'=>$tb->date,
			'form'=>EXPORT_XMLTIME,
			'zone'=>$tb->tz,
			'lang'=>'en',
		) . $tb->tz;
		$trackback_field .= '<trackback>' . "\n";
		$trackback_field .= '<title>' . $tb->subj . '</title>' . "\n";
		$trackback_field .= '<excerpt><![CDATA[' . $tb->body . ']]></excerpt>' . "\n";
		$trackback_field .= '<blog_name>' . $tb->name . '</blog_name>' . "\n";
		$trackback_field .= '<url>' . $tb->url . '</url>' . "\n";
		$trackback_field .= '<host>' . $tb->host . '</host>' . "\n";
		$trackback_field .= '<date>' . $date . '</date>' . "\n";
		$trackback_field .= '</trackback>' . "\n";
	}
	$cms->tag('export_entry_pings'=>$trackback_field);
}
sub _export_common_parts
{
	my $cms = shift;
	my %var = @_;
	&sb::Content::_common_parts($cms,%var);
	$cms->tag('site_encoding'=>EXPORT_XMLCHARSET);
}
sub _export_com_and_tb
{
	my $id = shift;
	my $type = shift;
	my @check = sb::Data->load($type,
		'sort'   => 'date',
		'cond'   => {'stat'=>1,'eid'=>$id},
		'order'  => 0,
	);
	my @array = ();
	for (my $i=0;$i<@check;$i++)
	{
		my $obj = sb::Data->load($type,'id'=>$check[$i]->id);
		push(@array,$obj) if ($obj);
	}
	return @array;
}
sub _export_body_text
{
	my $cms   = shift;
	my $entry = shift;
	my %var   = @_;
	$cms->tag('entry_description'=>$entry->body) if ($entry->body ne '');
	$cms->tag('entry_sequel'=>$entry->more) if ($entry->more ne '');
	$cms->tag('entry_excerpt'=>$entry->sum);
}
# ==================================================
# // private functions - for import
# ==================================================
sub _import_data
{
	my $self = shift;
	my $data = shift;
	my $type = DATATYPE_TXT; # DATATYPE_XML, DATATYPE_TD2, DATATYPE_TXT
	my $code = DEFAULT_CODE;
	$data = &_unify_linefeed($data);
	$code = sb::Language->get->checkcode($data);
	$data = sb::Language->get->convert($data) if ($code ne sb::Language->get->charcode);
	$data = substr($data, 3) if ($code eq 'utf8' and substr($data,0,3) eq pack('CCC',0xef,0xbb,0xbf)); # remove BOM for utf-8
	$type = DATATYPE_XML if ($data =~ /^<\?xml /); # SimpleXML
	$type = DATATYPE_TD2 if ($data =~ /^TDIARY2/); # TDIARY2
	return $self->_parse_xml($data) if ($type eq DATATYPE_XML);
	return $self->_parse_td2($data) if ($type eq DATATYPE_TD2);
	return $self->_parse_txt($data) if ($type eq DATATYPE_TXT);
	return undef;
}
sub _parse_xml
{ # SimpleXML format
	my $self = shift;
	my $data = shift;
	$data = &_remove_cdata($data);
	my $parser = new XML::Parser::Lite;
	$parser->setHandlers(
		Init  => \&_xml_init,
		Final => \&_xml_final,
		Start => \&_xml_start,
		Char  => \&_xml_char,
		End   => \&_xml_end,
	);
	$parser->parse($data);
	return $self->_convert_data_from_xml();
}
sub _parse_td2
{ # TDIARY2 format
	my $self = shift;
	my $data = shift;
	my $type = 'entry'; 
	$type = 'trackback' if ($data =~ /^TDIARY2\.(.*?)\-TRACKBACK/);
	$type = 'message'   if ($data =~ /^TDIARY2\.(.*?)\-COMMENTS/);
	my @entries    = ();
	my @messages   = ();
	my @trackbacks = ();
	my @ent_ids    = ();
	foreach my $text (split(/\n\.\n/,$data))
	{
		next if ($text eq '');
		my $flag = 0;
		my $check = undef;
		my %elem = ();
		TD2_DATA: foreach my $line (split("\n",$text))
		{
			if (!$line and !$flag)
			{
				$flag = 1;
				$elem{'body'} = '';
				next TD2_DATA;
			}
			if ($flag)
			{
				$line =~ s/^\.\././; # period at the beggin of the line
				if ($type ne 'trackback')
				{ # entry or comment
					$elem{'body'} .= $line . "\n" if ($type ne 'trackback');
				}
				else
				{ # trackback
					$elem{'url'}  = $line if ($flag == 1);
					$elem{'name'} = $line if ($flag == 2);
					$elem{'subj'} = $line if ($flag == 3);
					$elem{'body'} .= $line . "\n" if ($flag == 4);
					$flag++ if ($flag < 4);
				}
			}
			elsif ($line =~ /Date:\s(\d\d\d\d)(\d\d)(\d\d)/i)
			{
				my $date = $self->_convert_date($line);
				if ($type eq 'entry')
				{
					$elem{'date'} = $date;
					$elem{'tz'} = sb::Config->get->value('conf_timezone'); # [note] temporary
				}
				else
				{
					$check = sb::Data->load('Entry','cond'=>{'date'=>$date});
					last TD2_DATA if (!$check);
					$elem{'eid'} = $check->id;
				}
			}
			elsif ($line =~ /Title:\s(.*)/i)
			{
				$elem{'subj'} = $1 if ($type eq 'entry');
			}
			elsif ($line =~ /Visible:\s(.*)/i)
			{
				my $status = ($1 eq 'true') ? 1 : 0;
				$elem{'stat'} = $status;
			}
			elsif ($line =~ /Format:\s(.*)/i)
			{
				$elem{'form'} = $1 if ($type eq 'entry');
			}
			elsif ($line =~ /Mail:\s(.*)/i)
			{
				$elem{'mail'} = sb::Text->entitize($1) if ($type eq 'message');
			}
			elsif ($line =~ /Name:\s(.*)/i)
			{
				$elem{'auth'} = sb::Text->entitize($1) if ($type eq 'message');
			}
			elsif ($line =~ /Last-Modified:\s(.*)/i)
			{
				if ($type ne 'entry')
				{
					$elem{'date'} = $1;
					$elem{'tz'} = sb::Config->get->value('conf_timezone'); # [note] temporary
				}
			}
		} # end of TD2_DATA
		if ($type eq 'entry' and $elem{'body'} ne '')
		{
			my $entry = sb::Data->add('Entry',%elem);
			if ($entry)
			{
				$entry->acm(1);
				$entry->atb(1);
				$entry->auth($self->{'user'}->id);
				$entry->edit($self->{'user'}->id);
				push(@entries,$entry);
			}
		}
		elsif ($type eq 'message' and $check)
		{
			my $message = sb::Data->add('Message',%elem);
			if ($message)
			{
				push(@messages,$message);
				push(@ent_ids,$check->id);
			}
		}
		elsif ($type eq 'trackback' and $check)
		{
			my $trackback = sb::Data->add('Trackback',%elem);
			if ($trackback)
			{
				push(@trackbacks,$trackback);
				push(@ent_ids,$check->id);
			}
		}
	} # end of foreach my $body (split(/\n\.\n/,$data))
	if ($type ne 'entry' and @ent_ids)
	{
		my %cnt;
		@ent_ids = grep(!$cnt{$_}++, @ent_ids);
		@entries = sb::Data->load('Entry','cond'=>{'id'=>\@ent_ids},'detail'=>'on');
		foreach my $entry (@entries)
		{
			next if (!$cnt{$entry->id});
			$entry->com( $entry->com + $cnt{$entry->id} ) if ($type eq 'message');
			$entry->tb( $entry->tb + $cnt{$entry->id} ) if ($type eq 'trackback');
		}
	}
	sb::Data->update(@entries) if (@entries);
	sb::Data->update(@messages) if (@messages);
	sb::Data->update(@trackbacks) if (@trackbacks);
	return($#entries + 1);
}
sub _parse_txt
{ # MovableType Text Log format
	my $self = shift;
	my $data = shift;
	my @entries    = ();
	my @messages   = ();
	my @trackbacks = ();
	my $aLogSep = '--------';
	my $aSubSep = '-----';
	$data =~ s/^$aLogSep//; # remove the beginning separator
	foreach my $text (split("\n$aLogSep\n",$data))
	{ # entries
		next if ($text eq '');
		my $entry = undef;
		my %elem = ();
		my (@local_msg,@local_tb);
		my ($head,@contents) = split(/^$aSubSep/m,$text);
		my ($cnum,$tnum) = (0,0);
		foreach my $line (split("\n",$head))
		{ # entry information
			next if ($line eq '');
			$line =~ s/^\s*//;
			$line =~ s/\s*$//;
			my ($key,$val) = split(':',$line,2);
			$val =~ s/^\s*//;
			HEAD_SWITCH: {
				$_ = $key;
				/^AUTHOR$/i && do
				{
					$elem{'auth'} = $self->_add_user($val);
					$elem{'edit'} = $self->{'user'}->id;
					last HEAD_SWITCH;
				};
				/^PRIMARY\sCATEGORY$/i && do
				{
					$elem{'cat'} = $self->_add_category($val);
					last HEAD_SWITCH;
				};
				/^CATEGORY$/i && do
				{
					# [TODO]
					last HEAD_SWITCH;
				};
				/^TITLE$/i && do
				{
					$elem{'subj'} = $val;
					last HEAD_SWITCH;
				};
				/^DATE$/i && do
				{
					$elem{'date'} = $self->_convert_date($val);
					$elem{'tz'} = sb::Config->get->value('conf_timezone'); # [note] temporary
					last HEAD_SWITCH;
				};
				/^STATUS$/i && do
				{
					$elem{'stat'} = ($val eq 'Publish') ? 1 : 0;
					last HEAD_SWITCH;
				};
				/^ALLOW\sCOMMENTS$/i && do
				{
					$elem{'acm'} = $val;
					last HEAD_SWITCH;
				};
				/^ALLOW\sPINGS$/i && do
				{
					$elem{'atb'} = $val;
					last HEAD_SWITCH;
				};
				/^CONVERT\sBREAKS$/i && do
				{
					$val = 1 if ($val eq '__default__');
					$elem{'form'} = $val;
					last HEAD_SWITCH;
				};
			}; # end of HEAD_SWITCH
		} # end of foreach my $line (split("\n",$head))
		foreach my $content (@contents)
		{
			$content =~ s/^\s*//;
			$content =~ s/\s*$//;
			if ($content =~ s/^BODY:\n//)
			{
				$elem{'body'} = $content;
			}
			elsif ($content =~ s/^EXTENDED\sBODY:\n//)
			{
				$elem{'more'} = $content;
			}
			elsif ($content =~ s/^EXCERPT:\n//)
			{
				$elem{'sum'} = $content;
			}
			elsif ($content =~ s/^KEYWORDS:\n//)
			{
				$elem{'key'} = $content;
			}
			elsif ($content =~ s/^COMMENT:\n//)
			{
				my %msg_elem = ();
				my $message = undef;
				my @lines = split("\n",$content);
				my ($i,$idx) = (0,0);
				READ_COM: foreach my $line (@lines)
				{
					$line =~ s/^\s*//;
					my ($key,$val) = split(':',$line,2);
					$val =~ s/^\s*//;
					if ($key =~ /AUTHOR/i)
					{
						$msg_elem{'auth'} = $val;
					}
					elsif ($key =~ /EMAIL/i)
					{
						$msg_elem{'mail'} = $val;
					}
					elsif ($key =~ /URL/i)
					{
						$msg_elem{'url'} = $val;
					}
					elsif ($key =~ /IP/i)
					{
						$msg_elem{'host'} = $val;
					}
					elsif ($key =~ /DATE/i)
					{
						$msg_elem{'date'} = $self->_convert_date($val);
						$msg_elem{'tz'} = sb::Config->get->value('conf_timezone'); # [note] temporary
					}
					else
					{
						$idx = $i;
						last READ_COM;
					}
					$i++;
				}
				$msg_elem{'body'} = join("\n",@lines[$idx..$#lines]);
				$msg_elem{'stat'} = 1;
				$message = sb::Data->add('Message',%msg_elem);
				if ($message)
				{
					push(@local_msg,$message);
					$elem{'com'}++;
				}
			}
			elsif ($content =~ s/^PING:\n//)
			{
				my %tb_elem = ();
				my $trackback = undef;
				my @lines = split("\n",$content);
				my ($i,$idx) = (0,0);
				READ_TB: foreach my $line (@lines)
				{
					$line =~ s/^\s*//;
					my ($key,$val) = split(':',$line,2);
					$val =~ s/^\s*//;
					if ($key =~ /TITLE/i)
					{
						$tb_elem{'subj'} = $val;
					}
					elsif ($key =~ /URL/i)
					{
						$tb_elem{'url'} = $val;
					}
					elsif ($key =~ /IP/i)
					{
						$tb_elem{'host'} = $val;
					}
					elsif ($key =~ /BLOG\sNAME/i)
					{
						$tb_elem{'name'} = $val;
					}
					elsif ($key =~ /DATE/i)
					{
						$tb_elem{'date'} = $self->_convert_date($val);
						$tb_elem{'tz'} = sb::Config->get->value('conf_timezone'); # [note] temporary
					}
					else
					{
						$idx = $i;
						last READ_TB;
					}
					$i++;
				}
				$tb_elem{'body'} = join("\n",@lines[$idx..$#lines]);
				$tb_elem{'stat'} = 1;
				$trackback = sb::Data->add('Trackback',%tb_elem);
				if ($trackback)
				{
					push(@local_tb,$trackback);
					$elem{'tb'}++;
				}
			} # end of elsif ($content =~ s/^PING:\n//)
		} # end of foreach my $content (@contents)
		$entry = sb::Data->add('Entry',%elem);
		if ($entry)
		{
			push(@entries,$entry);
			foreach (@local_msg,@local_tb)
			{
				$_->eid($entry->id);
			}
			push(@messages,@local_msg) if (@local_msg);
			push(@trackbacks,@local_tb) if (@local_tb);
		}
	} # end of foreach my $text (split("\n$aLogSep\n",$data))
	sb::Data->update(@entries) if (@entries);
	sb::Data->update(@messages) if (@messages);
	sb::Data->update(@trackbacks) if (@trackbacks);
	return($#entries + 1);
}
# ==================================================
# // private functions - instance method
# ==================================================
sub _convert_date
{
	my $self = shift;
	my $date = shift;
	if ($date =~ /(\d\d\d\d)\/(\d\d)\/(\d\d) (\d\d)\:(\d\d)\:(\d\d) ([\+-]\d\d\d\d)/ )
	{ # sb with Time Zone
		return sb::Time->convert(
			'year' => $1,
			'mon'  => $2,
			'day'  => $3,
			'hour' => $4,
			'min'  => $5,
			'sec'  => $6,
			'zone' => $7,
		);
	}
	elsif ($date =~ /(\d\d\d\d)\/(\d\d)\/(\d\d) (\d\d)\:(\d\d)\:(\d\d)/)
	{ # JUGEM
		return sb::Time->convert(
			'year' => $1,
			'mon'  => $2,
			'day'  => $3,
			'hour' => $4,
			'min'  => $5,
			'sec'  => $6,
			'zone' => sb::Config->get->value('conf_timezone'),
		);
	}
	elsif ($date =~ /Date:\s(\d\d\d\d)(\d\d)(\d\d)/i)
	{ # tDiary
		return sb::Time->convert(
			'year' => $1,
			'mon'  => $2,
			'day'  => $3,
			'zone' => sb::Config->get->value('conf_timezone'),
		);
	}
	elsif ($date =~ /(\d\d)\/(\d\d)\/(\d\d\d\d) (\d\d)\:(\d\d)\:(\d\d) (\w\w)/)
	{ # Movable Type (12hours)
		my $ho = $4;
		my $mm = $7;
		$ho += 12 if ($mm eq 'PM' and $ho < 12);
		return sb::Time->convert(
			'year' => $3,
			'mon'  => $1,
			'day'  => $2,
			'hour' => $ho,
			'min'  => $5,
			'sec'  => $6,
			'zone' => sb::Config->get->value('conf_timezone'),
		);
	}
	elsif ($date =~ /(\d\d)\/(\d\d)\/(\d\d\d\d) (\d\d)\:(\d\d)\:(\d\d)/)
	{ # Movable Type (24hours)
		return sb::Time->convert(
			'year' => $3,
			'mon'  => $1,
			'day'  => $2,
			'hour' => $4,
			'min'  => $5,
			'sec'  => $6,
			'zone' => sb::Config->get->value('conf_timezone'),
		);
	}
	return($self->{'time'});
}
sub _add_category
{
	my $self = shift;
	my $name = shift;
	my @names = split(" &gt; ", $name);
	my $cat = undef;
	my $main = undef;
	while (my $catname = shift @names)
	{
		$main = ($cat) ? $cat->id : undef;
		$cat = $self->create_category(
			'name'=>$catname,
			'main'=>$main,
			'sub'=>(($main) ? 1 : undef)
		);
	}
	my $catid = ($cat) ? $cat->id : undef;
	return ($catid, $main);
}
sub _add_user
{
	my $self = shift;
	my $real = shift;
	my $id   = undef;
	my @check = ();
	return( $self->{'user'}->id ) if ($self->{'flag'} eq 'on' or $real eq '');
	foreach my $user ( values(%{$self->{'users'}}) )
	{ # check the existed user
		push(@check,$user->name);
		next if ($user->real ne $real);
		$id = $user->id;
	}
	if ($id eq '')
	{
		my $user = sb::Data->add('User');
		if ($user)
		{
			my $name = ($real =~ /^[a-zA-Z0-9_\-\.]+$/) ? $real : DEFAULT_USERNAME . $user->id;
			my $dupl = grep(/^\Q$name\E$/,@check);
			while ($dupl)
			{ # create unique name to avoid duplication
				$name = DEFAULT_USERNAME . $user->id . '_' . int(rand(NAME_TAILSEED));
				$dupl = grep(/^\Q$name\E$/,@check);
			}
			$user->name($name);
			$user->real($real);
			$user->pass($self->{'pass'});
			sb::Data->update($user);
			$self->{'users'}->{$user->id} = $user; # update instance as well
			$id = $user->id;
		}
		else
		{ # if failed, just allocates for default user
			$id = $self->{'user'}->id;
		}
	}
	return($id);
}
# ==================================================
# // private functions - handlers for xml
# ==================================================
sub _convert_data_from_xml
{
	my $self = shift;
	my @entries    = ();
	my @messages   = ();
	my @trackbacks = ();
	for (my $i=0;$i<@{$mImport{'entry'}};$i++)
	{
		my $new = $mImport{'entry'}->[$i];
		my ($cat, $add) = $self->_add_category(&_categoryname_for_JUGEM($new->{'category'}));
		$add = ',' . $add . ',' if ($add);
		my $userid = $self->_add_user($new->{'author'});
		my $user = ($self->{'user'}->id ne $userid) ? sb::Data->load('User', 'id'=>$userid) : $self->{'user'};
		my %elem = (
			'subj' => $new->{'title'},
			'cat'  => $cat,
			'auth' => $userid,
			'stat' => ($new->{'status'} eq 'Publish' or $new->{'status'} eq '') ? 1 : 0,
			'file' => &_restore_cdata($new->{'filename'}),
			'date' => $self->_convert_date($new->{'date'}),
			'tz'   => sb::Config->get->value('conf_timezone'), # [note] temporary
			'add'  => (($user->get_option('auto_cat')) ? $add : undef),
			'edit' => $self->{'user'}->id,
			'com'  => ($new->{'cnum'} + 1),
			'tb'   => ($new->{'tnum'} + 1),
			'acm'  => ($new->{'allowcomments'} eq '') ? 1 : $new->{'allowcomments'},
			'atb'  => ($new->{'allowpings'} eq '')    ? 1 : $new->{'allowpings'},
			'form' => ($new->{'convertbreaks'} eq '') ? 0 : $new->{'convertbreaks'},
			'body' => &_restore_cdata($new->{'description'}),
			'more' => &_restore_cdata($new->{'sequel'}),
			'sum'  => &_restore_cdata($new->{'excerpt'}),
			'key'  => &_restore_cdata($new->{'keyword'}),
			'tmp'  => undef,
		);
		my $entry = sb::Data->add('Entry',%elem);
		if ($entry)
		{
			push(@entries,$entry);
			for (my $j=0;$j<$entry->com;$j++)
			{
				my $msg_new = $mImport{'entry'}->[$i]->{'cbuf'}->[$j];
				my $body = &_restore_cdata($msg_new->{'description'});
				$body =~ s/<br \/>//g;
				my %msg_elem = (
					'eid'  => $entry->id,
					'stat' => 1,
					'date' => $self->_convert_date($msg_new->{'date'}),
					'tz'   => sb::Config->get->value('conf_timezone'), # [note] temporary
					'body' => $body,
					'agnt' => undef,
					'auth' => $msg_new->{'name'},
					'host' => $msg_new->{'host'},
					'mail' => $msg_new->{'email'},
					'url'  => $msg_new->{'url'},
				);
				my $message = sb::Data->add('Message',%msg_elem);
				push(@messages,$message) if ($message);
			}
			for (my $j=0;$j<$entry->tb;$j++)
			{
				my $tb_new = $mImport{'entry'}->[$i]->{'tbuf'}->[$j];
				my %tb_elem = (
					'eid'  => $entry->id,
					'stat' => 1,
					'date' => $self->_convert_date($tb_new->{'date'}),
					'tz'   => sb::Config->get->value('conf_timezone'), # [note] temporary
					'body' => &_restore_cdata($tb_new->{'excerpt'}),
					'subj' => $tb_new->{'title'},
					'name' => $tb_new->{'blog_name'},
					'url'  => $tb_new->{'url'},
					'host' => $tb_new->{'host'},
				);
				my $trackback = sb::Data->add('Trackback',%tb_elem);
				push(@trackbacks,$trackback) if ($trackback);
			}
		}
	}
	sb::Data->update(@entries) if (@entries);
	sb::Data->update(@messages) if (@messages);
	sb::Data->update(@trackbacks) if (@trackbacks);
	return($#entries + 1);
}
sub _xml_init
{
	my $xml = shift;
	%mImport = (
		'tag'       => undef,
		'flag'      => undef,
		'type'      => undef,
		'num'       => -1,
		'entry'     => [],
		'category'  => [],
	);
}
sub _xml_final
{
	my $xml = shift;
	return();
}
sub _xml_start
{
	my $xml = shift;
	my $tag = shift;
	$mImport{'tag'} = $tag;
	if ($tag eq 'entries')
	{
		$mImport{'flag'} = 1;
	}
	elsif ($mImport{'flag'})
	{
		if ($tag eq 'entry')
		{
			$mImport{'num'}++;
			$mImport{'type'} = $tag;
			$mImport{'entry'}->[$mImport{'num'}] = {};
			$mImport{'entry'}->[$mImport{'num'}]->{'cbuf'} = [];
			$mImport{'entry'}->[$mImport{'num'}]->{'cnum'} = -1;
			$mImport{'entry'}->[$mImport{'num'}]->{'tbuf'} = [];
			$mImport{'entry'}->[$mImport{'num'}]->{'tnum'} = -1;
		}
		elsif ($tag eq 'comments')
		{
			$mImport{'type'} = $tag if ($mImport{'num'} > -1);
		}
		elsif ($tag eq 'comment')
		{
			if ($mImport{'type'} eq 'comments')
			{
				my $cnum = $mImport{'entry'}->[$mImport{'num'}]->{'cnum'} + 1;
				$mImport{'entry'}->[$mImport{'num'}]->{'cnum'} = $cnum;
				$mImport{'entry'}->[$mImport{'num'}]->{'cbuf'}->[$cnum] = {};
			}
		}
		elsif ($tag eq 'trackbacks')
		{
			$mImport{'type'} = $tag if ($mImport{'num'} > -1);
		}
		elsif ($tag eq 'trackback')
		{
			if ($mImport{'type'} eq 'trackbacks')
			{
				my $tnum = $mImport{'entry'}->[$mImport{'num'}]->{'tnum'} + 1;
				$mImport{'entry'}->[$mImport{'num'}]->{'tnum'} = $tnum;
				$mImport{'entry'}->[$mImport{'num'}]->{'tbuf'}->[$tnum] = {};
			}
		}
	} # end of if ($mImport{'flag'})
}
sub _xml_char
{
	my $xml  = shift;
	my $elem = shift;
	if ($mImport{'flag'} and $mImport{'tag'})
	{
		my $num = $mImport{'num'};
		my $tag = $mImport{'tag'};
		if ($mImport{'type'} eq 'entry')
		{
			$mImport{'entry'}->[$num]->{$tag} = $elem;
		}
		elsif ($mImport{'type'} eq 'comments')
		{
			my $cnum = $mImport{'entry'}->[$num]->{'cnum'};
			$mImport{'entry'}->[$num]->{'cbuf'}->[$cnum]->{$tag} = $elem if ($cnum > -1);
		}
		elsif ($mImport{'type'} eq 'trackbacks')
		{
			my $tnum = $mImport{'entry'}->[$num]->{'tnum'};
			$mImport{'entry'}->[$num]->{'tbuf'}->[$tnum]->{$tag} = $elem if ($tnum > -1);
		} 
	} # end of if ($mImport{'flag'} and $mImport{'tag'})
}
sub _xml_end
{
	my $xml = shift;
	my $tag = shift;
	if ($tag eq 'entries')
	{
		$mImport{'flag'} = undef;
	}
	$mImport{'tag'} = undef;
}
# ==================================================
# // private functions - utilities
# ==================================================
sub _categoryname_for_JUGEM
{
	my $name = shift;
	$name = (split('##',$name,2))[1] if (index($name,'##') > -1);
	return($name);
}
sub _unify_linefeed
{
	my $text = shift;
	$text =~ s/\x0D\x0A/\n/g;
	$text =~ tr/\x0D\x0A/\n\n/;
	return($text);
}
sub _remove_cdata
{
	my $text = shift;
	my $output = '';
	my $tail = $2 if ( $text =~ /(.*)\]\]\>(.*)/s );
	while ( $text =~ s/(.*?)<\!\[CDATA\[(.*?)\]\]\>//s )
	{
		$output .= $1 . '&sbx;' . sb::Text->entitize($2);
	}
	$output .= $tail;
	return($output);
}
sub _restore_cdata
{
	my $text = shift;
	if ($text =~ /^&sbx;/)
	{
		$text =~ s/^&sbx;//;
		$text = sb::Text->detitize($text);
	}
	return($text);
}
1;
__END__
