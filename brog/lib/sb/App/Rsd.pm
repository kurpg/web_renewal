# sb::App::Rsd - Module for Serene Bach
# == written by T.Otani <takuya.otani@gmail.com> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

package sb::App::Rsd;

use strict;

# ==================================================
# // module version
# ==================================================
use vars qw( $VERSION @ISA );
$VERSION = '0.01';
# 0.01 [2005/10/18] changed run to pass TemplateManager object to sb::Content
# 0.00 [2005/08/11] generated

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
sub TEMPLATE_FILE  (){ 'default_rsd.xml' };
sub CONTENT_TYPE   (){ 'text/xml' };
sub OUTPUT_CHARSET (){ 'utf-8' };
# ==================================================
# // public functions
# ==================================================
sub run { # main routine
	my $class = shift;
	my $self = $class->SUPER::new( @_ );
	my $base = $self->load_template('file'=>TEMPLATE_FILE);
	if ($base ne '') {
		$base = sb::Content->output(sb::TemplateManager->new($base),
			'mode'      => 'page',
			'time'      => $self->{'time'},
			'cat'       => {}, # dummy
			'entry'     => {}, # dummy
			'entry_num' => 0,
			'extend' => {
				'main' => {
					'_main' => \&_add_entry_urls,
				},
			},
		);
	}
	print sb::Interface->get->head('type'=>CONTENT_TYPE,'charset'=>OUTPUT_CHARSET) . $base;
}
# ==================================================
# // private functions - contents extensions
# ==================================================
sub _add_entry_urls {
	my $cms = shift;
	my %var = @_;
	sb::Content::_common_parts($cms,%var);
	$cms->tag('rsd_xml_entry_url'=>$var{'conf'}->value('conf_srv_cgi') . $var{'conf'}->value('basic_xmlrpc'));
}
1;
__END__
=head1 NAME

sb::App::Rsd - Serene Bach application for Really Simple Discoverability

=head1 SYNOPSIS

	require sb::App::Rsd;
	sb::App::Rsd->run();

=head1 DESCRIPTION

sb::App::Rsd output Really Simple Discoverability as XML.
ref. http://archipelago.phrasewise.com/rsd

Normally this app is indicated as follow in <head>.
	<link rel="EditURI" type="application/rsd+xml" title="RSD" href="{site_rsd}" />

=head1 AUTHOR

Takuya Otani http://serenebach.net/

=head1 LICENSE

Copyright (C) 2004- Takuya Otani(SimpleBoxes) and SerendipityNZ

=cut
