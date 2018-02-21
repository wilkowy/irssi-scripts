#############################################
##  Channel announcement by wilk/xorandor  ##
#############################################
#
# /callnicks [message]
#  Grabs all channel nicks and sends them onto channel (hilight). Can
#   send additional message as an action.
#
#####
#
# v1.0 (20180219)
#  - extracted from my old script and made it public
#

use strict;
use warnings;
use vars qw($VERSION %IRSSI);
use Irssi qw(theme_register command_bind printformat signal_stop settings_add_str settings_get_str);

$VERSION = '1.0';
%IRSSI = (
	name		=> 'callnicks',
	description	=> 'Hilights all nicks on channel and sends a message',
	authors		=> 'wilk',
	contact		=> 'wilk @ IRCnet',
	license		=> 'GNU GPL v2 or any later version',
	changed		=> '19.02.2018',
	url			=> 'https://scripts.irssi.org'
);

Irssi::theme_register([
	'callnicks_error',	'Not connected to server or not on channel',
]);

sub cmd_callnicks {
	my ($text, $server, $channel) = @_;
	printformat(MSGLEVEL_CRAP, 'callnicks_error'), return if (!$server || !$server->{connected} || !$channel || ($channel->{type} ne 'CHANNEL'));
	my @ignored = split(/ /, lc settings_get_str('callnicks_ignore'));
	my @nicks;
	foreach my $user (sort { lc($a->{nick}) cmp lc($b->{nick}) } $channel->nicks()) {
		my $nick = $user->{nick};
		next if (grep { $_ eq lc($nick) } @ignored);
		next if (lc($nick) eq lc($server->{nick}));
		push(@nicks, $nick);
	}
	my $list = join(' ', @nicks);
	$server->command("msg $channel->{name} $list") if ($list ne '');
	$server->command("action $channel->{name} $text") if ($text ne '');
}

sub cmd_help {
	my ($cmd, $server, $window) = @_;
	$cmd =~ s/^\s+|\s+$//g;
	if (lc($cmd) eq 'callnicks') {
		print CLIENTCRAP;
		print CLIENTCRAP 'CALLNICKS [message]';
		print CLIENTCRAP;
		print CLIENTCRAP 'Grabs all channel nicks and sends them onto channel (hilight). Can send additional message as an action. Channel announcement / call to action.';
		print CLIENTCRAP;
		signal_stop();
	}
}

command_bind('help',		'cmd_help');
command_bind('callnicks',	'cmd_callnicks');

settings_add_str($IRSSI{'name'}, 'callnicks_ignore', '');
