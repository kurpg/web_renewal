# sb::Ping - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Ping;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.09';
# 0.09 [2009/05/27] modified send_trackback to set correct ping url
# 0.08 [2007/02/15] changed _ping_myself to fix a bug
# 0.07 [2007/02/14] changed new to handle error message / added ua, error as accessor
# 0.06 [2007/02/14] changed send_trackback to check eid correctly
# 0.05 [2005/10/01] changed _encode_text to convert charset correctly
# 0.04 [2005/07/16] changed _ping_myself to change the order of building files
# 0.03 [2005/07/11] changed config variable "srv_cgi" to "conf_srv_cgi"
# 0.02 [2005/07/07] fixed checking status during sending update ping was wrong.
# 0.01 [2005/06/01] fixed returning value %status in send_trackback/send_update was wrong.
# 0.00 [2005/02/28] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use HTTP::Request ();
use LWP::UserAgent ();
use sb::Language ();
use sb::Config ();
use sb::TemplateManager ();
use sb::Data ();
use sb::Build ();
use sb::App::Admin ();
@ISA = qw( sb::App::Admin );
# ==================================================
# // declaration for constant value
# ==================================================
sub METHOD_UPDATE (){ 'weblogUpdates.ping' };
sub METHOD_DEBUG  (){ 'weblogDebug.ping' };
# ==================================================
# // constructor
# ==================================================
sub new
{
	my $class = shift;
	my $self = {
		'ua'    => $class->SUPER::init_agent,
		'error' => {},
	};
	return bless( $self, $class );
}
# ==================================================
# // public functions
# ==================================================
sub ua
{
	my $self = shift;
	$self->{'ua'};
}
sub error
{
	my $self = shift;
	$self->{'error'};
}
sub send_trackback
{ # send trackback ping
	my $self = shift;
	my %param = (
		'url'       => undef,
		'excerpt'   => undef,
		'title'     => undef,
		'blog_name' => undef,
		'charset'   => 'UTF-8',
		'list'      => [],
		'local'     => sb::Config->get->value('conf_srv_cgi') . sb::Config->get->value('basic_tb'),
		'eid'       => undef,
		'now'       => undef,
		@_
	);
	my %status = (
		'sent'  => [],
		'error' => [],
	);
	if (!$self->ua)
	{
		$self->{'error'} = 'failed initialization';
		return;
	}
	if (!$param{'url'})
	{
		$self->{'error'} = 'no url of entry';
		return;
	}
	if (!@{$param{'list'}})
	{
		$self->{'error'} = 'no ping url';
		return;
	}
	if (!defined($param{'eid'}))
	{
		$self->{'error'} = 'no id for entry';
		return;
	}
	my $code = sb::Language->get->code_for_charset($param{'charset'});
	my $content = '';
	{ # get rid of duplicated urls
		my %cnt;
		@{$param{'list'}} = grep(!$cnt{$_}++, @{$param{'list'}});
	}
	foreach my $key ( keys(%param) )
	{
		next if ($key eq 'list' or $key eq 'local' or $key eq 'eid' or $key eq 'now');
		$content .= '&' if ($content ne '');
		$content .= $key . '=' . &_encode_text($param{$key},$code);
	}
	foreach my $tb_url ( @{$param{'list'}} )
	{
		my $request;
		if ( index($tb_url,'?') > -1 )
		{
			$request = HTTP::Request->new(GET => $tb_url . '&' . $content);
		}
		else
		{
			$request = HTTP::Request->new(POST => $tb_url);
			$request->content_type('application/x-www-form-urlencoded');
			$request->content($content);
		}
		my $check = undef;
		if ( index($tb_url,$param{'local'}) > -1 )
		{
			$check = $self->_ping_myself($tb_url,%param);
		}
		else
		{ # outer
			my $response = $self->ua->request($request);
			$check = (index($response->code,'2') == 0 and $response->content =~ /<error>0<\/error>/s);
			if ($check == 0)
			{
				$self->{'error'}->{$tb_url} = (index($response->code,'2') == 0)
					? 'response content : ' . $response->content
					: 'response code : ' . $response->code;
			}
		}
		push(@{$status{($check) ? 'sent' : 'error'}},$tb_url);
	}
	return( \%status );
}
sub send_update
{ # send update ping
	my $self = shift;
	my %param = (
		'list' => [],
		'mode' => undef,
		'name' => undef,
		'url'  => sb::Config->get->value('conf_srv_base'),
		'code' => 'utf8',
		@_
	);
	my %status = (
		'sent'  => [],
		'error' => [],
	);
	my $lang = sb::Language->get;
	return( undef ) if ( !$self->ua );
	return( undef ) if ( !@{$param{'list'}} );
	{ # get rid of duplicated urls
		my %cnt;
		@{$param{'list'}} = grep(!$cnt{$_}++, @{$param{'list'}});
	}
	$param{'name'} = $lang->convert($param{'name'},$param{'code'}) if ( $lang->charcode ne $param{'code'} );
	my $content = &_generate_update_ping_content(
		'method' => ($param{'mode'} ne 'ping') ? METHOD_DEBUG : METHOD_UPDATE,
		'params' => [$param{'name'},$param{'url'}],
	);
	foreach my $ping_url ( @{$param{'list'}} )
	{
		my $request = HTTP::Request->new(POST => $ping_url);
		$request->content_type('text/xml');
		$request->content($content);
		my $response = $self->ua->request($request);
		if ( index($response->code,'2') == 0 )
		{
			my $check = ( $response->content =~ /flerror.*?<boolean>(\d+)/s )[0];
			$self->{'error'}->{$ping_url} = 'response content : ' . $response->content if ($check);
			push(@{$status{($check) ? 'error' : 'sent'}},$ping_url);
		}
		else
		{
			$self->{'error'}->{$ping_url} = 'response code : ' . $response->code;
			push(@{$status{'error'}},$ping_url);
		}
	}
	return( \%status );
}
sub discover_trackback
{ # search and find trackback url from the text
	my $self = shift;
	my $text = shift;
	my @found = ();
	my @urls = &_find_url($text);
	return( undef ) if ( !$self->ua );
	foreach my $url (@urls)
	{
		my $response = $self->ua->get($url);
		if ( index($response->{'_rc'},'2') == 0 )
		{
			my $ping_url = &_search_pingurl($response->{'_content'}, $url);
			push(@found,$ping_url) if ($ping_url ne '');
		}
	}
	return( @found );
}
# ==================================================
# // private functions
# ==================================================
sub _ping_myself
{
	my $self = shift;
	my $url = shift;
	my %param = @_;
	my $dest = ($url =~ /(\d+?)$/)[0];
	if ($dest eq '' or $param{'eid'} eq $dest)
	{
		$self->{'error'}->{$url} = 'internal : wrong id';
		return;
	}
	my $entry = sb::Data->load('Entry','id'=>$dest);
	if (!$entry)
	{
		$self->{'error'}->{$url} = 'internal : no entry';
		return;
	}
	if ($entry->atb == 0)
	{
		$self->{'error'}->{$url} = 'internal : rejected';
		return;
	}
	foreach my $key ( 'excerpt','title','blog_name' )
	{
		$param{$key} =~ s/\'/&#39;/g;
	}
	my %tb = ( # trackback data
		'eid'  => $entry->id,
		'stat' => ($entry->atb == 1) ? 1 : 0,
		'date' => $param{'now'},
		'body' => $param{'excerpt'},
		'subj' => $param{'title'},
		'name' => $param{'blog_name'},
		'url'  => $param{'url'},
		'host' => sb::Interface->get->value('_addr'),
	);
	my $num = $entry->tb;
	my $new = sb::Data->add('Trackback',%tb);
	$entry->tb( ++$num ) if ($new->stat == 1);
	sb::Data->update($new);
	sb::Data->update($entry);
	{ # build proccess
		my %cat  = sb::Data->load_as_hash('Category');
		my %user = sb::Data->load_as_hash('User');
		my $builder = sb::Build->new(
			'time'      => time(),
			'user'      => \%user,
			'cat'       => \%cat,
			'sortedcat' => [ sort { $b->order <=> $a->order } values(%cat) ],
			'blog'      => sb::Data->load('Weblog','id'=>0),
		);
		if (sb::Config->get->value('conf_entry_archive') eq 'Individual')
		{
			$builder->build_javascript('recent_trackback_list');
			$builder->build_entry( $entry ) if ($entry->stat != 0);
		}
		elsif (sb::Config->get->value('conf_entry_archive') eq 'Monthly')
		{
			my $month = sb::Time->format(
				'time'=>$entry->date,
				'form'=>'%Year%%Mon%',
				'zone'=>$entry->tz
			);
			$builder->build_monthly_archive( $month );
		}
		$builder->build_category_index( $entry->cat ) if ($entry->cat ne '');
		$builder->build_top_page;
	}
	return(1);
}
sub _encode_text
{
	my ($text,$code) = @_;
	my $lang = sb::Language->get;
	if ( $lang->charcode ne $code )
	{
		$lang->checkcode($text, $lang->charcode);
		$text = $lang->convert($text,$code);
	}
	$text =~ s/\'/&#39;/g;
	$text =~ s/(\W)/'%' . unpack('H2', $1)/eg;
	return($text);
}
sub _generate_update_ping_content
{
	my %param = (
		'method' => METHOD_UPDATE,
		'params' => [],
		@_
	);
	my $num = 0;
	my $cms = sb::TemplateManager->new( &_template_update_ping() );
	$cms->num(0);
	$cms->tag('sb_ping_methodname'=>$param{'method'});
	foreach my $para ( @{$param{'params'}} )
	{
		$cms->num($num);
		$cms->tag('sb_ping_param'=>$para);
		$num++;
	}
	$cms->block('sb_ping_params'=>$num);
	return $cms->output;
}
sub _template_update_ping
{
	return <<'__UPDATE_PING_TEMP__';
<?xml version="1.0"?>
<methodCall>
<methodName>{sb_ping_methodname}</methodName>
<params>
<!-- BEGIN sb_ping_params -->
<param><value>{sb_ping_param}</value></param>
<!-- END sb_ping_params -->
</params>
</methodCall>
__UPDATE_PING_TEMP__
}
sub _search_pingurl
{
	my ($text,$url) = @_;
	my $found = '';
	my @rdfs = $text =~ /(<rdf:RDF.*?<\/rdf:RDF>)/smg;
	foreach my $rdf ( @rdfs )
	{
		my $identifier = ( $rdf =~ /dc:identifier=\"(.*?)\"/sm )[0];
		my $ping_url   = ( $rdf =~ /trackback:ping=\"(.*?)\"/sm )[0];
		$found = $ping_url if ($identifier ne '' and $ping_url ne '' and $identifier eq $url);
		last if ($found ne '');
	}
	return($found);
}
sub _find_url
{
	my $text = shift;
	$text =~ tr/\x0D\x0A//d;
	my @urls = $text =~ /s?https?:\/\/[-_.!~*\'()a-zA-Z0-9;\/?:\@&=+\$,%#]+/g;
	{ # get rid of duplicated urls
		my %cnt;
		@urls = grep(!$cnt{$_}++, @urls);
	}
	return @urls;
}
1; # end of package
__END__
