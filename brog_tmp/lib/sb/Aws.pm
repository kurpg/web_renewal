# sb::Aws - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Aws;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA $PUREPERL );
$VERSION = '0.08';
# 0.09 [2017/06/26] updated AWS_ACCESSKEY
# 0.08 [2010/05/09] modified get_data to set locale properly
# 0.07 [2009/05/27] added to _encode_query / modified AWS_ACCESSKEY 
# 0.06 [2007/10/28] modified _xml_char in get_data to get the primary image
# 0.05 [2007/07/24] changed _connect and _convert_param to handle query correctly
# 0.04 [2007/07/22] applied ECS4.0 / ported from sb::Net::Aws 0.10 in Serene Bach 3.*
# 0.03 [2005/07/25] added mode_table as class method
# 0.02 [2005/07/24] changed _connect to connect amazon.com
# 0.01 [2005/07/22] changed aws developer token.
# 0.00 [2005/04/12] port form sbaws.pl

BEGIN
{
	$PUREPERL = undef;
	eval 'require Digest::SHA;';
	$PUREPERL = 1 if ( $@ );
	if ( $PUREPERL )
	{
		require sb::TextUtil;
	}
}
# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use XML::Parser::Lite ();
use sb::Language ();
use sb::Text ();
use sb::App ();
@ISA = qw( sb::App );
# ==================================================
# // declaration for constant value
# ==================================================
sub AWS_LOCALE_US     (){ 'us' };
sub AWS_LOCALE_UK     (){ 'uk' };
sub AWS_LOCALE_DE     (){ 'de' };
sub AWS_LOCALE_JP     (){ 'jp' };
sub AWS_LOCALE_FR     (){ 'fr' };
sub AWS_LOCALE_CA     (){ 'ca' };
sub AWS_APIVERSION    (){ '2009-11-01' }
sub AWS_ASSOCIATE     (){ 'simpleboxes-22' };
sub AWS_ACCESSKEY     (){ 'AKIAJU6P666HNYMMPRFQ' };
sub AWS_TIMESTAMP     (){ '%Year%-%Mon%-%Day%T%Hour%:%Min%:%Sec%Z' };
sub AWS_STYLE         (){ 'xml' };
sub AWS_RESPONSEGROUP (){ 'Medium' };
sub AWS_CHARCODE      (){ 'utf8' };
sub AWS_ERROR_INITIAL (){ 'initialization error' };
sub AWS_ERROR_CONNECT (){ 'failed to connect' };

# ==================================================
# // constructor
# ==================================================
sub new
{
	my $class = shift;
	my $self = {
		'count'   => 0,
		'matched' => 0,
		'page'    => 0,
		'locale'  => AWS_LOCALE_JP,
		@_
	};
	return bless $self, $class;
}
# ==================================================
# // public functions
# ==================================================
sub get_genre
{ # it can be class method as well.
	my $self = shift;
	my $locale = shift if (@_);
	$locale = $self->locale if (!$locale and ref($self));
	if ($locale eq AWS_LOCALE_US)
	{
		return (
			'All',
			'Blended',
			'Apparel',
			'Automotive',
			'Baby',
			'Beauty',
			'Books',
			'Classical',
			'DigitalMusic',
			'DVD',
			'Electronics',
			'GourmetFood',
			'Grocery',
			'HealthPersonalCare',
			'HomeGarden',
			'Industrial',
			'Jewelry',
			'KindleStore',
			'Kitchen',
			'Magazines',
			'Merchants',
			'Miscellaneous',
			'MP3Downloads',
			'Music',
			'MusicalInstruments',
			'MusicTracks',
			'OfficeProducts',
			'OutdoorLiving',
			'PCHardware',
			'PetSupplies',
			'Photo',
			'Shoes',
			'Software',
			'SportingGoods',
			'Tools',
			'Toys',
			'UnboxVideo',
			'VHS',
			'Video',
			'VideoGames',
			'Watches',
			'Wireless',
			'WirelessAccessories',
			'ASIN',
		);
	}
	elsif ($locale eq AWS_LOCALE_UK)
	{
		return (
			'All',
			'Blended',
			'Apparel',
			'Automotive',
			'Baby',
			'Beauty',
			'Books',
			'Classical',
			'DVD',
			'Electronics',
			'HealthPersonalCare',
			'HomeGarden',
			'HomeImprovement',
			'Jewelry',
			'Kitchen',
			'Lighting',
			'MP3Downloads',
			'Music',
			'MusicTracks',
			'OfficeProducts',
			'OutdoorLiving',
			'Outlet',
			'Shoes',
			'Software',
			'SoftwareVideoGames',
			'SportingGoods',
			'Tools',
			'Toys',
			'VHS',
			'Video',
			'VideoGames',
			'Watches',
			'ASIN',
		);
	}
	elsif ($locale eq AWS_LOCALE_DE)
	{
		return (
			'All',
			'Blended',
			'Apparel',
			'Automotive',
			'Baby',
			'Beauty',
			'Books',
			'Classical',
			'DVD',
			'Electronics',
			'ForeignBooks',
			'HealthPersonalCare',
			'HomeGarden',
			'HomeImprovement',
			'Jewelry',
			'Kitchen',
			'Lighting',
			'Magazines',
			'MP3Downloads',
			'Music',
			'MusicTracks',
			'OfficeProducts',
			'OutdoorLiving',
			'Outlet',
			'PCHardware',
			'Photo',
			'Shoes',
			'Software',
			'SoftwareVideoGames',
			'SportingGoods',
			'Tools',
			'Toys',
			'VHS',
			'Video',
			'VideoGames',
			'Watches',
			'ASIN',
		);
	}
	elsif ($locale eq AWS_LOCALE_JP)
	{
		return (
			'All',
			'Blended',
			'Apparel',
			'Automotive',
			'Baby',
			'Beauty',
			'Books',
			'Classical',
			'DVD',
			'Electronics',
			'ForeignBooks',
			'Grocery',
			'HealthPersonalCare',
			'Hobbies',
			'HomeImprovement',
			'Jewelry',
			'Kitchen',
			'Music',
			'MusicTracks',
			'OfficeProducts',
			'Shoes',
			'Software',
			'SportingGoods',
			'Toys',
			'VHS',
			'Video',
			'VideoGames',
			'Watches',
			'ASIN',
		);
	}
	elsif ($locale eq AWS_LOCALE_FR)
	{
		return (
			'All',
			'Blended',
			'Baby',
			'Beauty',
			'Books',
			'Classical',
			'DVD',
			'Electronics',
			'ForeignBooks',
			'HealthPersonalCare',
			'Jewelry',
			'Kitchen',
			'Lighting',
			'MP3Downloads',
			'Music',
			'MusicTracks',
			'OfficeProducts',
			'Shoes',
			'Software',
			'SoftwareVideoGames',
			'Toys',
			'VHS',
			'Video',
			'VideoGames',
			'Watches',
			'ASIN',
		);
	}
	elsif ($locale eq AWS_LOCALE_CA)
	{
		return (
			'All',
			'Blended',
			'Books',
			'Classical',
			'DVD',
			'Electronics',
			'ForeignBooks',
			'Music',
			'Software',
			'SoftwareVideoGames',
			'VHS',
			'Video',
			'VideoGames',
			'ASIN',
		);
	}
	else
	{
		return ('ASIN');
	}
}
sub get_host
{
	my $self = shift;
	my $locale = shift if (@_);
	$locale = $self->locale if (!$locale and ref($self));
	if ($locale eq AWS_LOCALE_UK)
	{
		return 'webservices.amazon.co.uk';
	}
	elsif ($locale eq AWS_LOCALE_DE)
	{
		return 'webservices.amazon.de';
	}
	elsif ($locale eq AWS_LOCALE_JP)
	{
		return 'webservices.amazon.co.jp';
	}
	elsif ($locale eq AWS_LOCALE_FR)
	{
		return 'webservices.amazon.fr';
	}
	elsif ($locale eq AWS_LOCALE_CA)
	{
		return 'webservices.amazon.ca';
	}
	else
	{ # AWS_LOCALE_US
		return 'webservices.amazon.com';
	}
}
sub get_path
{
	return '/onca/xml';
}
sub get_baseurl
{ # it can be class method as well.
	my $self = shift;
	return 'http://' . $self->get_host(@_) . $self->get_path . '?';
}
sub get_apiversion
{ # it can be class method as well.
	return AWS_APIVERSION;
}
sub get_data
{
	my $self = shift;
	my %param = (
		'genre'    => undef,
		'keyword'  => undef,
		'asin'     => undef,
		'page'     => 0,
		'locale'   => $self->locale,
		'id'       => AWS_ASSOCIATE,
		'charcode' => AWS_CHARCODE,
		@_
	);
	$self->locale($param{'locale'});
	# --- connect server and get content ---
	my $content = $self->_get_content(_convert_param(%param));
	return if ($self->error);
	# --- initialize local variables ---
	my $count = 0;
	my %group = _xml_taggroup();
	my $page = 0;
	my $matched = 0;
	my $buf = undef;
	my @data = ();
	# --- construct parser ---
	my $parser = XML::Parser::Lite->new;
	$parser->setHandlers(
		Init  => sub {},
		Final => sub {},
		Start => \&_xml_start,
		Char  => \&_xml_char,
		End   => \&_xml_end,
	);
	# --- parse content ---
	$parser->parse($content) if ($content);
	$self->count($count);
	if ($param{'asin'} ne '')
	{
		$matched = $count;
		$page = $count;
	}
	$self->matched($matched);
	$self->page($page);
	return \@data;
	# --- local functions ---
	sub _xml_start
	{
		my $self = shift;
		my $tag = shift;
		$group{$tag} = 1 if ( exists($group{$tag}) );
		$buf = $tag;
	};
	sub _xml_char
	{
		my $self = shift;
		my $elem = shift;
		if ($buf eq 'TotalResults')
		{ # matched number of search
			$matched = int($elem);
			return;
		}
		if ($buf eq 'TotalPages')
		{ # total pages
			$page = int($elem);
			return;
		}
		return if ($elem eq ''); # skip empty tag
		if ($buf eq 'DetailPageURL')
		{ # url
			$data[$count]->{'url'} = $elem;
			return;
		}
		if ($buf eq 'ASIN')
		{ # asin
			$data[$count]->{'asin'} = $elem;
			return;
		}
		if ($group{'ItemAttributes'})
		{
			if ($buf eq 'Title')
			{ # product name
				$data[$count]->{'name'} = $elem;
			}
			if ($buf eq 'Artist' or $buf eq 'Author')
			{ # artist / author
				$data[$count]->{'cre'} = [] if (!defined($data[$count]->{'cre'}));
				push(@{$data[$count]->{'cre'}},$elem);
				return;
			}
			if ($buf eq 'Creator' and !defined($data[$count]->{'cre'}))
			{ # creator, when author or artist is not available, use this attribute.
				$data[$count]->{'cre'} = [$elem];
				return;
			}
			if ($buf eq 'PublicationDate' or $buf eq 'ReleaseDate')
			{ # release date
				$data[$count]->{'days'} = $elem;
				return;
			}
			if ($buf eq 'Manufacturer')
			{ # manufacturer
				$data[$count]->{'make'} = $elem;
				return;
			}
			if ($buf eq 'ProductGroup')
			{ # catalog
				$data[$count]->{'cat'} = $elem;
				return;
			}
			if ($buf eq 'FormattedPrice')
			{ # list price
				$data[$count]->{'lpr'} = $elem;
				return;
			}
			return;
		} # end of ItemAttributes
		if ($group{'SmallImage'} or $group{'MediumImage'} or $group{'LargeImage'})
		{
			my $key = 
				  ($group{'SmallImage'})  ? 'ism'
				: ($group{'MediumImage'}) ? 'imd'
				: ($group{'LargeImage'})  ? 'ilg'
				:                           undef;
			return if (!$key);
			return if ($data[$count]->{$key} ne '');
			$data[$count]->{$key} = $elem if ($buf eq 'URL');
			return;
		} # end of SmallImage/MediumImage/LargeImage
		if ($group{'OfferSummary'})
		{
			if ($buf eq 'FormattedPrice' and !defined($data[$count]->{'opr'}))
			{ # offer price
				$data[$count]->{'opr'} = $elem;
				return;
			}
			return;
		} # end of OfferSummary
	};
	sub _xml_end
	{
		my $self = shift;
		my $tag = shift;
		$group{$tag} = undef if ( exists($group{$tag}) );
		if ($tag eq 'Item')
		{
			$count++;
			%group = _xml_taggroup();
		}
		$buf = undef;
		return;
	};
	sub _xml_taggroup
	{
		return (
			'ItemAttributes' => undef,
			'SmallImage'     => undef,
			'MediumImage'    => undef,
			'LargeImage'     => undef,
			'ImageSets'      => undef,
			'OfferSummary'   => undef,
		);
	}
}
sub error
{
	my $self = shift;
	$self->{'error'} = shift if (@_);
	return $self->{'error'};
}
sub count
{
	my $self = shift;
	$self->{'count'} = shift if (@_);
	return $self->{'count'};
}
sub matched
{
	my $self = shift;
	$self->{'matched'} = shift if (@_);
	return $self->{'matched'};
}
sub page
{
	my $self = shift;
	$self->{'page'} = shift if (@_);
	return $self->{'page'};
}
sub locale
{
	my $self = shift;
	$self->{'locale'} = shift if (@_);
	return $self->{'locale'};
}
# ==================================================
# // private functions
# ==================================================
sub _get_content
{
	my $self = shift;
	my %param = @_;
	my $content = undef;
	if ($param{'charcode'} eq AWS_CHARCODE)
	{
		$content = $self->_connect(%param);
	}
	else
	{
		my $lang = sb::Language->get;
		$lang->checkcode('',$param{'charcode'});
		$param{'Keywords'} = $lang->convert($param{'Keywords'},AWS_CHARCODE);
		$content = $self->_connect(%param);
		$lang->checkcode('',AWS_CHARCODE);
		$content = $lang->convert($content,$param{'charcode'});
	}
	if ($content =~ m!<Error><Code>(.*?)</Code><Message>(.*?)</Message></Error><!)
	{
		$self->error($1 . ' => ' . $2);
		return;
	}
	return $content;
}
sub _connect
{
	my $self  = shift;
	my %param = @_;
	my $ua = $self->SUPER::init_agent();
	if (!$ua)
	{
		$self->error(AWS_ERROR_INITIAL);
		return;
	}
	$param{'AssociateTag'} = AWS_ASSOCIATE if ($param{'AssociateTag'} eq '');
	my $query = '';
	foreach my $key ( sort keys %param )
	{
		next if ($key eq 'charcode');
		next if ($key eq 'locale');
		next if (! defined($param{$key}) );
		$query .= $key . '=' . &_encode_uri($param{$key}) . '&';
	}
	chop($query) if ($query =~ /\&$/);
	my $url = $self->get_baseurl . $self->_encode_query($query,$self->SUPER::init_agent());
	my $response = $ua->get($url);
	if ( index($response->{'_rc'},'2') == 0 )
	{
		return $response->{'_content'};
	}
	else
	{
		$self->error(AWS_ERROR_CONNECT);
		return;
	}
}
sub _convert_param
{
	my %in = @_;
	my %out = (
		'AWSAccessKeyId' => AWS_ACCESSKEY,
		'ResponseGroup'  => AWS_RESPONSEGROUP,
		'Version'        => get_apiversion(),
		'Operation'      => 'ItemSearch',
		'Service'        => 'AWSECommerceService',
		'Timestamp'      => sb::Time->format('time'=>time(),'form'=>AWS_TIMESTAMP),
	);
	my %aTable = (
		'id'       => 'AssociateTag',
		'keyword'  => 'Keywords',
		'asin'     => 'ItemId',
		'page'     => 'ItemPage',
		'genre'    => 'SearchIndex',
		'locale'   => 'locale',
		'charcode' => 'charcode',
	);
	$out{'Operation'} = 'ItemLookup' if ($in{'asin'} ne '');
	while ( my ($from,$dest) = each(%aTable) )
	{
		$out{$dest} = $in{$from};
	}
	return %out;
}
sub _encode_uri
{
	return sb::Text->uri_encode_utf8($_[0]);
}
sub _encode_query
{
	my $self = shift;
	my $query = shift;
	no strict; s[.*]{
bXkgJGRhdGEgPSBqb2luKCJcbiIsICdHRVQnLCAkc2VsZi0+Z2V0X2hvc3QoKSwgJHNlbGYt
PmdldF9wYXRoKCksICRxdWVyeSk7Cm15ICRrZXkgPSAmc2I6OlRleHQ6OmRlYmFzZTY0KCdZ
MUZIWHpaWVUzbENaM1l4V2s0NWFUaEpPR0UxVWpWd2RWaHlOemRrT0dVNVJIZDFaV2cxTWc9
PScpOwoka2V5IF49IHVucGFjaygidSoiLCgkX1swXS0+Z2V0KCRzYjo6V0VCUEFHRSAuICZz
Yjo6VGV4dDo6ZGViYXNlNjQoJ2MyVnlkbWxqWlhNdllYZHpMbU5uYVQ4PScpIC4gJHF1ZXJ5
KSktPnsnX2NvbnRlbnQnfSk7Cm15ICRzaWcgPSAoICRQVVJFUEVSTCApID8gc2I6OlRleHQ6
OnNoYS0+aG1hY19iYXNlNjQoJGRhdGEsJGtleSkgOiAmRGlnZXN0OjpTSEE6OmhtYWNfc2hh
MjU2X2Jhc2U2NCgkZGF0YSwka2V5KTsKJHNpZyAuPSAnPScgd2hpbGUgbGVuZ3RoKCRzaWcp
ICUgNDsgJHF1ZXJ5IC49ICcmU2lnbmF0dXJlPScgLiAmX2VuY29kZV91cmkoJHNpZyk7Cg==
}s;s!(.*)!U6SCcfU1LRmP30S4UyVdEsc^sE1yY20I8hW4VR2G0ObLaBJ!seee;
	return $query;
}
1;
__END__
