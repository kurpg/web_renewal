# sb::Interface - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Interface;

use strict;

# ==================================================
# // Module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.07';
# 0.07 [2012/05/27] modified how to check xmlrpc request from Content-Type.
# 0.06 [2012/02/22] changed set_cookie to make sure value does not end with ','
# 0.05 [2007/03/06] changed head
# 0.04 [2006/11/27] changed head to output status
# 0.03 [2005/08/08] changed head to output http header correctly
# 0.02 [2005/07/14] changed _parse_data to parse remote_host more precisely
# 0.01 [2005/06/08] changed set_cookie not to set domain field for cookie
# 0.00 [2004/11/xx] generated

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Time ();
use sb::Language ();
# ==================================================
# // declaration for constant value
# ==================================================
sub LF            (){ "\x0D\x0A" }
sub TIME_FORMAT   (){ '%Week%, %DayShort%-%MonShort%-%YearLong% %Hour24%:%Min%:%Sec% GMT' }
sub HOURS_PER_DAY (){ 24 };
sub SECS_PER_HOUR (){ 3600 };
# ==================================================
# // declaration for class member
# ==================================================
my %mIn = ();     # 送信フォームデータ
my @mIn = ();     # マルチパート送信時のヘッダ格納
my $mXmlrpc = 0;  # XML-RPC用フラグ
my $mCookie = ''; # クッキーデータ(出力用)
# ==================================================
# // declaration for private variables
# ==================================================
my $pObject = undef; # オブジェクト
# ==================================================
# // constructor
# ==================================================
sub get {
	my $class = shift;
	return($pObject) if ( defined($pObject) );
	$pObject = bless({},$class);
	$pObject->_parse_data(@_);
	return($pObject);
}
sub new {
	&get; # 'new' is alias for 'get'
}
# ==================================================
# // destructor
# ==================================================
sub bye {
	my $class = shift;
	$pObject = undef;
}
sub DESTROY {
	my $self = shift;
	%mIn = ();
	@mIn = ();
	$mXmlrpc = 0;
	$mCookie = '';
	return();
}
# ==================================================
# // public functions
# ==================================================
sub value { # [accessor] 指定したキーの取得
	my $self = shift;
	my $key  = shift;
	return ( $key and defined($mIn{$key}) ) ? $mIn{$key} : undef;
}
sub names { # [accessor] キーの取得
	my $self = shift;
	return( keys( %mIn ) );
}
sub xmlflag { # [accessor] XML-RPC用フラグ
	my $self = shift;
	return( $mXmlrpc );
}
sub content_list { # [accessor] マルチパート送信時のヘッダリスト
	my $self = shift;
	return( @mIn );
}
sub head
{ # output http head
	my $self = shift;
	my %param = ( # input parameters
		'location' => '',                         # [optional][URI.] address to forward
		'charset'  => sb::Language->get->charset, # [optional][CHAR] character set
		'type'     => 'text/html',                # [optional][CHAR] Content-Type
		'cache'    => 0,                          # [optional][NUM.] chache expires day
		'length'   => undef,                      # [optional][NUM.] Content-Length
		'status'   => '200 OK',                   # [optional][CHAR] http response code
		@_,
	);
	my @output = ();
	push(@output,$mCookie) if ($mCookie ne '');
	push(@output,'Content-length: ' . $param{'length'} . LF) if ( defined($param{'length'}) );
	if ($param{'location'} ne '')
	{
		my ($hash,$query) = ();
		$param{'status'} = '302 Moved';
		($param{'location'},$hash)  = split('\#',$param{'location'},2) if (index($param{'location'},'#') > -1);
		($param{'location'},$query) = split('\?',$param{'location'},2) if (index($param{'location'},'?') > -1);
		$param{'location'} .= '?' . $query;
		$param{'location'} .= '#' . $hash if ($hash ne '');
		push(@output,'Status: ',$param{'status'},LF);
		push(@output,'Location: ',$param{'location'},LF);
		push(@output,'Content-Type: ',$param{'type'},'; charset=',$param{'charset'},';',LF);
		push(@output,LF); # boundary between head and body
		push(@output,'<html><head><meta http-equiv="Refresh" content="0;URL=',$param{'location'},'"></head></html>',LF);
	}
	else
	{
		push(@output,'Status: ',$param{'status'},LF);
		push(@output,'Content-Type: ',$param{'type'},'; charset=',$param{'charset'},';',LF) if ($param{'type'} ne '');
		if ($param{'cache'} > 0)
		{
			push(@output,'Pragma: no-cache',LF);
			push(@output,'Cache-Control: no-store, no-cache, must-revalidate, post-check=0, pre-check=0',LF);
			push(@output,'Expires: ',sb::Time->format('time'=>$param{'cache'},'form'=>TIME_FORMAT),LF);
		}
		push(@output,LF); # boundary between head and body
	}
	return( join('',@output) );
}
sub cookie { # [accessor] get cookie parameters
	my $self = shift;
	my %cookie = ();
	my %param = ( # input parameters
		'name' => undef, # [required][CHAR] cookie name
		@_,
	);
	if ( defined($param{'name'}) ) {
		my (@cookies,%cookie_base);
		@cookies = split(/;/,$ENV{'HTTP_COOKIE'});
		foreach (@cookies) {
			my ($cook_key,$cook_val) = split(/=/,$_);
			$cook_key =~ s/ //g;
			$cookie_base{$cook_key} = $cook_val;
		}
		@cookies = split(/,/,$cookie_base{$param{'name'}});
		foreach (@cookies)
		{
			if (/<>/)
			{
				my ($cook_key,$cook_val) = split('<>',$_);
				$cookie{$cook_key} = &_decode_uri($cook_val);
			}
			else
			{
				$cookie{$param{'name'}} = &_decode_uri($_);
			}
		}
	}
	return( \%cookie );
}
sub clear_cookie { # clear cookie parameters
	my $self = shift;
	$mCookie = '';
	return();
}
sub set_cookie { # set cookie parameters
	my $self = shift;
	my %param = ( # input parameters
		'time'   => undef, # [required][NUM.] current time
		'name'   => undef, # [required][CHAR] cookie name
		'expire' => 10,    # [optional][NUM.] expires day
		'path'   => '',    # [optional][URI.] path
		'data'   => undef, # [optional][HASH] stored data
		'secure' => undef, # [optional][SEL.] secure flag / if set as 1, cokkie is issued as secure
		@_,
	);
	if ( defined($param{'time'}) and defined($param{'name'}) ) {
		my ($cookie,$date,$cook_path) = ();
		$date = sb::Time->format(
			'time' => $param{'time'} + ($param{'expire'} * HOURS_PER_DAY * SECS_PER_HOUR),
			'form' => TIME_FORMAT,
		);
		my @cookie_data = ();
		if (!defined($param{'data'}))
		{
			$param{'data'} = { $param{'name'} => 'on' };
		}
		if (ref($param{'data'}) eq 'HASH')
		{
			@cookie_data = map { $_ . '<>' . &_encode_uri($param{'data'}->{$_}) } keys(%{$param{'data'}});
		}
		else
		{
			@cookie_data = ( &_encode_uri($param{'data'}) );
		}
		$cookie .= join(',',@cookie_data);
		if ($param{'path'} ne '' and $param{'path'} =~ /http:\/\/(.*?)\/(.*)\//) {
			# $cook_path = ' domain=' . $1 . '; path=/' . $2 . '/;';
			$cook_path = ' path=/' . $2 . '/;'; # to avoid not saving cookie at localhost.
		} else {
			$cook_path = '';
		}
		$mCookie .= "Set-Cookie: $param{'name'}=$cookie; expires=$date;$cook_path";
		$mCookie .= ' secure;' if ($param{'secure'});
		$mCookie .= LF;
	}
	return();
}
# ==================================================
# // private functions
# ==================================================
sub _parse_data { # from cgi-lib.pl 2.18 / Copyright (c) 1993-1999 Steven E. Brenner
	my $self = shift;
	my %param = (
		'max_data'   => 102400,   # maximum bytes to accept via POST - 2^17
		'write_file' => 0,        # directory to which to write files, or 0 if files should not be written
		'file_pre'   => 'clform', # Prefix of file names, in directory above
		'buf_size'   => 8129,     # default buffer size when reading multipart
		'max_bound'  => 100,      # maximum boundary length to be encounterd
		@_
	);
	my %incfn; # Client's filename (may not be provided)
	my %inct;  # Client's content-type (may not be provided)
	my %insfn; # Server's filename (for spooled files)
	my ($in, $len, $type, $meth, $got, $name) = ();
	binmode(STDIN);  # we need these for DOS-based systems
	binmode(STDOUT); # and they shouldn't hurt anything else 
	binmode(STDERR);
	# Get several env variables
	$type = $ENV{'CONTENT_TYPE'};
	$len  = $ENV{'CONTENT_LENGTH'};
	$meth = $ENV{'REQUEST_METHOD'};
	if ($len > $param{'max_data'}) { 
		&_error("Request to receive too much data: $len bytes\n");
	}
	if (!defined $meth 
	  or $meth eq '' 
	  or $meth eq 'GET' 
	  or $meth eq 'HEAD' 
	  or $type =~ m/^application\/x-www-form-urlencoded(;|$)/) {
		my $cmdflag = 0;
		if (!defined $meth or $meth eq '') {
			$in = $ENV{'QUERY_STRING'};
			$cmdflag = 1;  # also use command-line options
		} elsif($meth eq 'GET' or $meth eq 'HEAD') {
			$in = $ENV{'QUERY_STRING'};
		} elsif ($meth eq 'POST') {
			&_error("[Short Read] wanted $len, got $got\n") if (($got = read(STDIN, $in, $len) != $len));
		} else {
			&_error("Unknown request method: $meth\n");
		}
		my $check_dec = (index($in,'mode=bm') > -1) ? 0 : 1;
		@mIn = split(/[&;]/,$in); 
		push(@mIn, @ARGV) if ( $cmdflag ); # add command-line parameters
		foreach my $i (0 .. $#mIn) {
			$mIn[$i] =~ s/\+/ /g;
			my ($key, $val) = split(/=/,$mIn[$i],2);
			$key = &_decode_uri($key) if ($check_dec);
			$val = &_decode_uri($val) if ($check_dec);
			$mIn{$key} .= "\0" if (defined($mIn{$key}));
			$mIn{$key} .= $val;
		}
	} elsif ($type =~ m/^multipart\/form-data/) {
		eval {
			die("Invalid request method for  multipart/form-data: $meth\n") if ($meth ne 'POST');
			my ($head, @heads, $cd, $ct, $fname, $ctype, $bpos, $lpos, $amt, $fn);
			my $serial = 0;
			my $bufsize = $param{'buf_size'};
			my $maxbound = $param{'max_bound'};
			my $writefiles = $param{'write_file'};
			my $buf = '';
			my ($boundary) = $type =~ /boundary="([^"]+)"/; #" # find boundary
			($boundary) = $type =~ /boundary=(\S+)/ unless $boundary;
			die("Boundary not provided: probably a bug in your server\n") unless $boundary;
			$boundary =  "--" . $boundary;
			my $blen = length($boundary);
			if ($writefiles) {
				stat ($writefiles);
				$writefiles = "/tmp" unless  -d _ && -w _;
				$writefiles .= "/$param{'file_pre'}"; 
			}
			my $left = $len;
			PART: while (1) { # find each part of the multi-part while reading data
				$amt = ($left > $bufsize + $maxbound - length($buf)) 
				     ? $bufsize + $maxbound - length($buf)
				     : $left;
				$got = read(STDIN, $buf, $amt, length($buf));
				die("[Short Read] wanted $amt, got $got\n") if ($got != $amt);
				$left -= $amt;
				$mIn{$name} .= "\0" if defined $mIn{$name}; 
				$mIn{$name} .= $fn if $fn;
				$name =~ /([-\w]+)/;  # This allows $insfn{$name} to be untainted
				if ( defined $1 ) {
					$insfn{$1} .= "\0" if defined $insfn{$1}; 
					$insfn{$1} .= $fn if $fn;
				}
				BODY: while (($bpos = index($buf, $boundary)) == -1) {
					if ($left == 0 && $buf eq '') {
						  foreach my $value (values %insfn) {
							unlink(split("\0",$value));
						}
						die("reached end of input while seeking boundary of multipart. Format of CGI input is wrong.\n");
					}
					if ($name) {  # if no $name, then it's the prologue -- discard
						if ($fn) {
							print CGI_FILE substr($buf, 0, $bufsize);
						} else {
							$mIn{$name} .= substr($buf, 0, $bufsize);
						}
					}
					$buf = substr($buf, $bufsize);
					$amt = ($left > $bufsize) ? $bufsize : $left; # $maxbound == length($buf);
					$got = read(STDIN, $buf, $amt, length($buf));
					die("[Short Read] wanted $amt, got $got\n") if ($got != $amt);
					$left -= $amt;
				} # end of BODY
				if (defined $name) {  # if no $name, then it's the prologue -- discard
					if ($fn) {
						print CGI_FILE substr($buf, 0, $bpos - 2);
					} else {
						$mIn{$name} .= substr($buf, 0, $bpos - 2); # kill last \r\n
					}
				}
				close (CGI_FILE);
				last PART if (substr($buf, $bpos + $blen, 2) eq "--");
				substr($buf, 0, $bpos + $blen + 2) = '';
				$amt = ($left > $bufsize + $maxbound - length($buf)) 
				     ? $bufsize + $maxbound - length($buf) 
				     : $left;
				$got = read(STDIN, $buf, $amt, length($buf));
				die("[Short Read] wanted $amt, got $got\n") if ($got != $amt);
				$left -= $amt;
				undef $head;
				undef $fn;
				HEAD: while (($lpos = index($buf, "\r\n\r\n")) == -1) { 
					if ($left == 0  && $buf eq '') {
						foreach my $value (values %insfn) {
							unlink(split("\0",$value));
						}
						die("reached end of input while seeking end of headers. Format of CGI input is wrong.\n$buf");
					}
					$head .= substr($buf, 0, $bufsize);
					$buf = substr($buf, $bufsize);
					$amt = ($left > $bufsize) ? $bufsize : $left; # $maxbound == length($buf);
					$got = read(STDIN, $buf, $amt, length($buf));
					die("[Short Read] wanted $amt, got $got\n") if ($got != $amt);
					$left -= $amt;
				} # end of HEAD
				$head .= substr($buf, 0, $lpos + 2);
				push(@mIn, $head);
				@heads = split("\r\n", $head);
				($cd) = grep (/^\s*Content-Disposition:/i, @heads);
				($ct) = grep (/^\s*Content-Type:/i, @heads);
				($name) = $cd =~ /\bname="([^"]+)"/i; #"; 
				($name) = $cd =~ /\bname=([^\s:;]+)/i unless defined $name;  
				($fname) = $cd =~ /\bfilename="([^"]*)"/i; #"; # filename can be null-str
				($fname) = $cd =~ /\bfilename=([^\s:;]+)/i unless defined $fname;
				$incfn{$name} .= (defined $mIn{$name} ? "\0" : "") . (defined $fname ? $fname : "");
				($ctype) = $ct =~ /^\s*Content-type:\s*"([^"]+)"/i;  #";
				($ctype) = $ct =~ /^\s*Content-Type:\s*([^\s:;]+)/i unless defined $ctype;
				$inct{$name} .= (defined $mIn{$name}) ? "\0" . $ctype : "" . $ctype;
				if ($writefiles && defined $fname) {
					$serial++;
					$fn = $writefiles . ".$$.$serial";
					open(CGI_FILE, ">$fn") or die("Couldn't open $fn\n");
					binmode(CGI_FILE); # write files accurately
				}
				substr($buf, 0, $lpos + 4) = '';
				undef $fname;
				undef $ctype;
			} # end of PART
		}; # end of eval
		if ($@) {
			foreach my $value (values %insfn) {
				unlink(split("\0",$value));
			}
			&_error($@);
		}
	} elsif ($type =~ m|/xml| and $meth eq 'POST') { # XML-RPC interface
		$got = read(STDIN, $in, $len);
		&_error("[Short Read] wanted $len, got $got\n") if ($got != $len);
		$in = &_linefeed($in);
		$mIn{'charset'} = $2 if ($in =~ /^<\?xml(.*?)encoding=\"(.*?)\"(.*?)>/s);
		$mIn{'methodName'} = $1 if ($in =~ /<methodName>(.*?)<\/methodName>/is);
		$mIn{'params'} = $1 if ($in =~ /<params>(.*?)<\/params>/is);
		$mXmlrpc = 1;
		@mIn = ();
	} else {
		&_error("Unknown Content-type: $ENV{'CONTENT_TYPE'}\n");
	}
	# Set global variables
	$mIn{'_path'} = $ENV{'PATH_INFO'};
	$mIn{'_refe'} = $ENV{'HTTP_REFERER'};
	$mIn{'_host'} = $ENV{'REMOTE_HOST'};
	$mIn{'_addr'} = $ENV{'REMOTE_ADDR'};
	$mIn{'_agnt'} = $ENV{'HTTP_USER_AGENT'};
	$mIn{'_host'} = $mIn{'_addr'} if ($mIn{'_host'} eq '');
	if ($mIn{'_host'} eq $mIn{'_addr'}) {
		$mIn{'_host'} = gethostbyaddr(pack('C4',split(/\./,$mIn{'_host'})),2) || $mIn{'_addr'};
	}
	return ( scalar(@mIn) ); 
}
sub _error { # from cgi-lib.pl 2.18 / Copyright (c) 1993-1999 Steven E. Brenner
	my (@msg) = @_;
	print 'Content-Type: text/html',LF;
	print LF;
	print "<html>\n<head>\n<title>sb::Interface : $msg[0]</title>\n</head>\n<body>\n";
	print "<h1>sb::Interface : $msg[0]</h1>\n";
	foreach my $i (1 .. $#msg) {
		print "<p>$msg[$i]</p>\n";
	}
	die @msg;
}
sub _linefeed { # unify linefeed code
	$_[0] =~ s/\x0D\x0A/\n/g;
	$_[0] =~ tr/\x0D\x0A/\n\n/;
	return($_[0]);
}
sub _decode_uri { # decode uri
	$_[0] =~ s/%([0-9A-Fa-f][0-9A-Fa-f])/pack('H2',$1)/eg;
	return($_[0]);
}
sub _encode_uri { # encode uri
	$_[0] =~ s/(\W)/'%' . unpack('H2', $1)/eg;
	return($_[0]);
}
1;
__END__
=head1 NAME

sb::Interface - cgi interface for sb

=head1 SYNOPSIS

	use sb::Interface;
	my $cgi = sb::Interface->new('max_data' => 102400);
	my $text = $cgi->value('text'); # gets value of <input name="text">

=head1 DESCRIPTION

[CGI Interface module]
sb::Interface parses recieved parameters and manages cookies.
sb::Intarface is based on cgi-lib.pl by Steven E. Brenner.

【CGI インタフェースモジュール】
cgi-lib.pl をベースに sb 向けにカスタマイズしています。

起動時にパースも行うので、CGI.pm と異なり、明示的なメソッド起動の必
要はありません。

=head1 AUTHOR

Takuya Otani http://serenebach.net/
based on cgi-lib.pl 2.18 / Copyright (c) 1993-1999 Steven E. Brenner

=head1 LICENSE

Copyright (C) 2004- Takuya Otani(SimpleBoxes) and SerendipityNZ

=cut
