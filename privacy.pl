########################################
##  Privacy checker by wilk/xorandor  ##
########################################
#
# /privacy
#  Lists joined channels visible to others (no s/p/a flag).
#  Supports multiple networks (appends network tag).
#
#####
#
# v1.0 (20180218)
#  - extracted from my old script and made it public
#

use strict;
use warnings;
use vars qw($VERSION %IRSSI);
use Irssi qw(theme_register command_bind printformat signal_stop servers);

$VERSION = '1.0';
%IRSSI = (
	name		=> 'privacy',
	description	=> 'Lists joined channels visible to others',
	authors		=> 'wilk',
	contact		=> 'wilk @ IRCnet',
	license		=> 'GNU GPL v2 or any later version',
	changed		=> '18.02.2018',
	url			=> 'https://scripts.irssi.org'
);

Irssi::theme_register([
	'privacy_list',		'Public channels (%_$0%_): $1',
]);

sub cmd_privacy {
	foreach my $srvr (sort { lc($a->{tag}) cmp lc($b->{tag}) } servers()) {
		my @chans;
		foreach my $chan (sort { lc($a->{name}) cmp lc($b->{name}) } $srvr->channels()) {
			my $modes = (split(/ /, $chan->{mode}))[0] // '';
			next if ($modes =~ /[psa]/);
			push(@chans, $chan->{ownnick}{prefixes} . $chan->{name});
		}
		printformat(MSGLEVEL_CRAP, 'privacy_list', $srvr->{tag}, join(', ', @chans));
	}
}

sub cmd_help {
	my ($cmd, $server, $window) = @_;
	$cmd =~ s/^\s+|\s+$//g;
	if (lc($cmd) eq 'privacy') {
		print CLIENTCRAP;
		print CLIENTCRAP 'PRIVACY';
		print CLIENTCRAP;
		print CLIENTCRAP 'Lists joined channels visible to others via /whois - those without "p"/"s" flag (&#! channels) or "a" flag (&! channels).';
		print CLIENTCRAP;
		signal_stop();
	}
}

command_bind('help',	'cmd_help');
command_bind('privacy',	'cmd_privacy');
