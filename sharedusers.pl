##########################################
##  Find shared users by wilk/xorandor  ##
##########################################
#
# /sharedusers [channel]
#  Finds shared users (joined to more than one channel with our
#   presence) globally (status) or against active channel. Provide
#   additional channel name to make cross-match between both of them
#   (users present on active channel and the other one).
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
use Irssi qw(theme_register command_bind printformat signal_stop channels);

$VERSION = '1.0';
%IRSSI = (
	name		=> 'sharedusers',
	description	=> 'Finds shared users globally or from active channel',
	authors		=> 'wilk',
	contact		=> 'wilk @ IRCnet',
	license		=> 'GNU GPL v2 or any later version',
	changed		=> '18.02.2018',
	url			=> 'https://scripts.irssi.org'
);

Irssi::theme_register([
	'sharedusers_user',			'Shared user: $0 ($1)',
	'sharedusers_count',		'Total shared users: $0',
	'sharedusers_no_shared',	'No shared users found',
]);

sub cmd_sharedusers {
	my ($args, $server, $channel) = @_;
	$args =~ s/^\s+|\s+$//g;
	my $withchan = (split(/ /, lc $args))[0] // '';
	my $global = 1;
	my %nicks;
	if ($channel && ($channel->{type} eq 'CHANNEL')) {
		$global = 0;
		%nicks = map { lc($_->{nick}) => '' } $channel->nicks();
	}
	my %shared;
	foreach my $chan (channels()) {
		foreach my $user ($chan->nicks()) {
			if (($global || exists($nicks{lc $user->{nick}})) && ($user->{nick} ne $chan->{server}{nick})) {
				push(@{$shared{$user->{nick}}}, $chan->{name} . ((lc($chan->{server}{tag}) ne lc($server->{tag})) ? ':' . $chan->{server}{tag} : ''));
			}
		}
	}
	my @users;
	my $shared = 0;
	foreach my $nick (sort { lc($a) cmp lc($b) } keys %shared) {
		if (@{$shared{$nick}} > 1) {
			if (($withchan eq '') || (grep { lc($_) eq lc($withchan) } @{$shared{$nick}})) {
				$shared++;
				printformat(MSGLEVEL_CRAP, 'sharedusers_user', $nick, join(', ', @{$shared{$nick}}));
			}
		}
	}
	if ($shared) {
		printformat(MSGLEVEL_CRAP, 'sharedusers_count', $shared);
	} else {
		printformat(MSGLEVEL_CRAP, 'sharedusers_no_shared');
	}
}

sub cmd_help {
	my ($cmd, $server, $window) = @_;
	$cmd =~ s/^\s+|\s+$//g;
	if (lc($cmd) eq 'sharedusers') {
		print CLIENTCRAP;
		print CLIENTCRAP 'SHAREDUSERS [channel]';
		print CLIENTCRAP;
		print CLIENTCRAP 'Finds shared users (joined to more than one channel with our presence) globally (status) or against active channel.';
		print CLIENTCRAP 'Provide additional channel name to make cross-match between both of them (users present on active channel and the other one).';
		print CLIENTCRAP;
		signal_stop();
	}
}

command_bind('help',		'cmd_help');
command_bind('sharedusers',	'cmd_sharedusers');
