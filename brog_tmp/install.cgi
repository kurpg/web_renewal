#!/usr/bin/perl
# 
# Serene Bach - weblog management system
# == written by T.Otani <ootani@segausers.gr.jp> ===
# == Copyright (C) 2004 SimpleBoxes/SerendipityNZ ==

use strict;
use lib qw(. ./lib ./ext);
require 'addlib.cgi' if (-r 'addlib.cgi');
eval {
	require sb;
	sb->run('app'=>'Install');
};
if ($@) {
	print "Content-Type: text/plain; charset=EUC-JP\n\n";
	print 'インストーラを起動できませんでした。',"\n\n";
	print '必要なライブラリがきちんと揃っているかご確認ください。',"\n\n";
	print 'error message from here',"\n",'----',"\n",$@;
}
exit(0);
