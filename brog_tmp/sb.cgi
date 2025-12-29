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
	sb->run('app' => 'Main');
};
print "Content-Type: text/plain\n\n",$@ if ($@);
exit(0);
