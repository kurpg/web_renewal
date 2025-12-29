# sb::Mailer - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::Mailer;

use strict;
# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.02';
# 0.02 [2007/07/12] fixed a bug in text_parse
# 0.01 [2007/07/04] merged Fuco's patch. Thx Fuco!
# 0.00 [2005/03/02] porting from sbmail.pl

# ==================================================
# // configuration for inheritance / dependancy
# ==================================================
use sb::Language ();
# ==================================================
# // constructor
# ==================================================
sub new
{
	my $class = shift;
	my $self  = {
		'default_user' => 'anonymous@example.com',
		'sender'       => 'sendmail',
		'send_server'  => '/usr/sbin/sendmail',
		'charcode'     => 'jis',
		'pop_server'   => undef,
		'pop_account'  => undef,
		'pop_password' => undef,
		'pop_useapop'  => 0,
		@_,
	};
	sb::Language->get->checkcode('',$self->{'charcode'});
	return bless($self,$class);
}
# ==================================================
# // public functions
# ==================================================
sub sendmail
{
	my $self = shift;
	my %param = (
		'To'      => undef,
		'From'    => $self->{'default_user'},
		'Subject' => 'no title',
		'Body'    => '',
		@_,
	);
	eval {
		die("no destination address\n") if (!$param{'To'});
		my $head = &_generate_header(%param);
		$param{'Body'} = sb::Language->get->mailtext($param{'Body'});
		if ($self->{'sender'} eq 'sendmail')
		{
			my $sendmail = $self->{'send_server'};
			my $from = $param{'From'};
			die("cannot use sendmail, please check the path for sendmail\n") if !(-x $sendmail);
			open(SENDMAIL,"| $sendmail -t -i -f '$from'") or die("cannot open via sendmail\n");
			print SENDMAIL $head;
			print SENDMAIL $param{'Body'};
			close(SENDMAIL);
		}
		elsif ($self->{'sender'} eq 'smtp')
		{
			require Net::SMTP;
			my $smtp = Net::SMTP->new(
				$self->{'send_server'},
				'Hello'=>$self->{'send_server'}
			);
			$smtp->mail($param{'From'});
			$smtp->to($param{'To'});
			$smtp->data();
			$smtp->datasend($head);
			$smtp->datasend($param{'Body'});
			$smtp->dataend();
			$smtp->quit;
		}
	};
	return ($@) ? $@ : undef; # return error message if failed
}
sub receive
{
	my $self = shift;
	my %param = (
		'subj'  => undef, # Subject of mail which will be received
		'msgid' => undef, # Received Message-ID (if the recived mail has same ID, it will be ignored)
		'from'  => undef, # Acceptable From address (array ref.)
		'size'  => undef, # Acceptable mail size (if it's set as -1, there is no limitation)
		'del'   => undef, # Flag for deleting the received mail from server (0 : no / 1 : delete)
		@_,
	);
	my @mail; # received mail
	if ( !defined($self->{'pop_server'}) 
	  or !defined($self->{'pop_account'}) 
	  or !defined($self->{'pop_password'}) )
	{
		die('Lack of parameters');
	}
	eval {
		require Net::POP3;
		my $pop3 = Net::POP3->new($self->{'pop_server'}) or die('Failed to connect.');
		my $check_auth = undef;
		if ($self->{'pop_useapop'})
		{
			$check_auth = $pop3->apop($self->{'pop_account'},$self->{'pop_password'});
		}
		else
		{
			$pop3->user($self->{'pop_account'});
			$check_auth = $pop3->pass($self->{'pop_password'});
		}
		die('Failed to authorize.') if !defined($check_auth);
		my $msglist = $pop3->list();
		foreach my $msgid (keys %$msglist)
		{
			my ($tmp,$data);
			next if (${$msglist}{$msgid} > $param{'size'} and $param{'size'} > -1); # exceed the size limit
			$tmp = $pop3->top($msgid); # get the header
			$data = join('',@$tmp);
			$data = &_linefeed($data);
			$data .= "\n" if ($data !~ /\n$/);
			$tmp = $self->extract_head($data,'Subject');
			next if ($tmp eq '');
			next if ($param{'subj'} ne '' and index($tmp,$param{'subj'}) == -1);
			if ($param{'from'})
			{
				my $frm_flag;
				$tmp = $self->extract_head($data,'From');
				foreach (@{$param{'from'}})
				{
					$frm_flag = 1 if (index($tmp,$_) > -1);
					last if ($frm_flag);
				}
				next if (!$frm_flag);
			}
			if ($param{'msgid'} ne '')
			{
				$tmp = $self->extract_head($data,'Message-ID');
				last if ($tmp eq $param{'msgid'}); # already received so we can leave
			}
			$tmp = $pop3->get($msgid); # get the mail (include body)
			$data = join('',@$tmp) . "\n.\n";
			$data = &_linefeed($data);
			push(@mail,$data);
			$pop3->delete($msgid) if ($param{'del'});
		}
		$pop3->quit;
	};
	die($@) if ($@);
	return(@mail);
	# [References] ============================================
	# Let's create POP3 client with Module (in Japanese)
	# http://x68000.q-e-d.net/~68user/net/module-pop3.html
	# Receiving mail by Perl (in Japanese)
	# http://homepage3.nifty.com/hippo2000/perltips/rcvmail.htm
	# =========================================================
}
sub text_parse
{
	my $self = shift;
	my $data = shift;
	my $out = {
		'head' => '',
		'body' => '',
		'boundary' => '',
	};
	$data =~ s/\.\n$/\n/; # delete the last period
	if ($data =~ /^(.*?)\n\n(.*?)\n$/s)
	{
		$out->{'head'} = $1 . "\n";
		$out->{'body'} = $2;
	}
	if ($out->{'head'} =~ /Content-Type:\s?multipart\/mixed;\n?\s?boundary=(?:[\"]?)([\w\'()+,-.\/:=? ]*[\w\'()+,-.\/:=?])[\"]?/soi)
	{
		$out->{'boundary'} = '--' . $1;
	}
	else
	{
		$out->{'boundary'} = '';
	}
	return($out);
}
sub multipart
{
	my $self = shift;
	my $data = shift; # should be outpout of text_parse
	my @out;
	my $boundary = $data->{'boundary'};
	my @parts = split(/\Q$boundary\E/, $data->{'body'});
	shift @parts; # we don't use the last part
	require 'mimeutil.pl';
	for (my $i=0;$i<@parts;$i++)
	{
		if($parts[$i] =~ /(.*?)\n\n(.*)/s)
		{
			my ($head,$body) = ($1,$2);
			$out[$i]->{'head'} = $head;
			$out[$i]->{'type'} = &_part_type($head);
			$out[$i]->{'code'} = &_part_encode($head);
			$out[$i]->{'name'} = &_part_name($head);
			if ($out[$i]->{'code'} =~ /Base64/i)
			{
				$out[$i]->{'body'} = &mimeutil::bodydecode($body,'b64');
				$out[$i]->{'body'} .= &mimeutil::bdeflush('b64');
			}
			elsif ($out[$i]->{'code'} =~ /Quoted/i)
			{
				$out[$i]->{'body'}  = &mimeutil::bodydecode($body,'qp');
				$out[$i]->{'body'} .= &mimeutil::bdeflush('qp');
			}
			else
			{
				$out[$i]->{'body'} = $body;
			}
		}
	}
	return(\@out);
}
sub extract_head
{
	my $self = shift;
	my ($head,$elem) = @_;
	my $out;
	require 'mimeutil.pl';
	if ($head =~ /$elem: (.*?)\n([\w|-]*?): /s)
	{ # not last header
		$out = $1;
	}
	elsif ($head =~ /$elem: (.*?)\n$/s)
	{ # the last header
		$out = $1;
	}
	$out = &mimeutil::mimedecode($out, 'EUC'); # we just use EUC code
	$out =~ s/\n\s?//g;
	$out =~ s/\s$//;
	return($out);
}
# ==================================================
# // private functions
# ==================================================
sub _generate_header
{
	my %param = @_;
	my $header;
	foreach my $key ( keys(%param) )
	{
		next if ($key eq 'Body');
		$header .= $key . ': ' . sb::Language->get->mailtext($param{$key}) . "\n";
	}
	$header .= 'MIME-Version: 1.0' . "\n";
	$header .= 'Content-type: text/plain; charset=' . sb::Language->get->string('parts_mailchar') . "\n";
	$header .= 'Content-Transfer-Encoding: 7bit' . "\n";
	$header .= 'X-Mailer: ' . $sb::PRODUCT . ' ' . $sb::VERSION . "\n";
	$header .= "\n"; # boundary between head and body
	require 'mimeutil.pl';
	return &mimeutil::mimeencode($header);
}
sub _linefeed
{
	$_[0] =~ s/\x0D\x0A/\n/g;
	$_[0] =~ tr/\x0D\x0A/\n\n/;
	return($_[0]);
}
sub _part_type
{ # extract Content-Type
	my $head = shift;
	return($1) if ($head =~ /Content-Type:\s?([^; \n]+)[;]?/si); # from RFC 2045
	return();
}
sub _part_name
{ # extract file name
	my $head = shift;
	if ($head =~ /Content-Disposition:\s?.*?;\n?\s*(filename\*.*)/soi)
	{ # from RFC 2231
		return &_decode_2231_filename($1);
	}
	# from http://www.meadowy.org/~gotoh/mew-fake-cdp.html
	return ($1) if ($head =~ /Content-Disposition:\s?.*?;\n?\s*filename=([^\s\"]+)/soi);
	if ($head =~ /Content-Disposition:\s?.*?;\n?\s*filename=[\"]?([^\"]+)[\"]?/soi)
	{
		require 'mimeutil.pl';
		return &mimeutil::mimedecode($1);
	}
	if ($head =~ /Content-Type:\s?.*?;\n?\s*name=\"([^\"]+)\"/soi)
	{ # invalid against RFC, but many clients implement like this
		require 'mimeutil.pl';
		return &mimeutil::mimedecode ($1);
	}
	return ($1) if ($head =~ /Content-Type:\s?.*?;\n?\s*name=([^\"\s]+)/soi);
	return ();
}
sub _decode_2231_filename
{
	my $head = shift;
	my $name = '';
	$name .= $1 while ($head =~ /filename\*[\d]*[\*]?=[\"]?([^;\"]*)[\"]?/g);
	if ($name and $name =~ /^(^[\w-]+)\'[\w]*\'(.*)/)
	{ # uri decode
		my $enc = $1;
		($name = $2) =~ s/%([0-9A-Fa-f][0-9A-Fa-f])/pack('H2',$1)/eg;
	}
	return ($name);
}
sub _part_encode
{ # extract encoding
	my $head = shift;
	return($1) if ($head =~ /Content-Transfer-Encoding:\s?([^\s]+)/oi); # from RFC 2045
	return();
}
1;
__END__
