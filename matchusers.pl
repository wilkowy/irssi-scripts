####################################
##  User search by wilk/xorandor  ##
####################################
#
# /matchusers [-a/n/i/h/r/f] <pattern> [channel]
#  Search for known users matching a pattern from all channels (status)
#   or from active channel. You may also give channel name to search
#   only there.
#  Supports multiple networks (appends network tag).
#
#  Options:
#   -a = match against nick!ident@host (default)
#   -n = match against nicks
#   -i = match against idents
#   -h = match against hosts
#   -r = match against real names (excluded from default search)
#   -f = display full hostname
#
#  Wildcards:
#   * - zero or more characters
#   ? - one character
#   % - one digit
#   & - one alphabetic character
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
	name		=> 'matchusers',
	description	=> 'Search for users matching criteria',
	authors		=> 'wilk',
	contact		=> 'wilk @ IRCnet',
	license		=> 'GNU GPL v2 or any later version',
	changed		=> '18.02.2018',
	url			=> 'https://scripts.irssi.org'
);

Irssi::theme_register([
	'matchusers_nicks',			'Matches (%_$0%_): $1',
	'matchusers_count',			'Total matches: $0',
	'matchusers_no_matches',	'No matches found for $0',
	'matchusers_no_channel',	'No such channel is joined',
	'matchusers_usage',			'Usage: /matchusers [-a/n/i/h/r/f] <pattern> [channel]',
]);

sub cmd_matchusers {
	my ($args, $server, $channel) = @_;
	$args =~ s/^\s+|\s+$//g;
	printformat(MSGLEVEL_CRAP, 'matchusers_usage'), return if ($args eq '');
	my ($id, $matchnick, $matchident, $matchhost, $matchname, $fullhost) = (0) x 7;
	my $matchuser = 1;
	my @args = split(/ /, $args);
	if (grep { $_ eq '-f' } @args) { $fullhost = 1; $id++; }
	if (grep { $_ eq '-n' } @args) { $matchnick = 1; $matchuser = 0; $id++; }
	if (grep { $_ eq '-i' } @args) { $matchident = 1; $matchuser = 0; $id++; }
	if (grep { $_ eq '-h' } @args) { $matchhost = 1; $matchuser = 0; $id++; }
	if (grep { $_ eq '-r' } @args) { $matchname = 1; $matchuser = 0; $id++; }
	if (grep { $_ eq '-a' } @args) { $matchuser = 1; $id++; }
	my $re_pattern = my $pattern = lc $args[$id];
	for ($re_pattern) {
		s/\\/\\\\/g; # must be first
		s/\./\\./g;
		s/\[/\\[/g; s/\]/\\]/g;
		s/\{/\\{/g; s/\}/\\}/g;
		s/\^/\\^/g;
		s/\|/\\|/g;
		s/\*/.*/g;
		s/\?/./g;
		s/\%/\\d/g;
		s/\&/\[a-zA-Z\]/g;
	}
	$re_pattern = "^$re_pattern\$";
	my $forchan = $args[$id + 1] // '';
	my $chan = ($forchan ne '') ? $server->channel_find($forchan) : undef;
	my @channels;
	if (defined $chan) {
		push(@channels, $chan);
	} elsif ($forchan ne '') {
		printformat(MSGLEVEL_CRAP, 'matchusers_no_channel');
		return;
	} elsif ($channel && ($channel->{type} eq 'CHANNEL')) {
		push(@channels, $channel);
	} else {
		@channels = channels();
	}
	my %users;
	foreach my $chan (@channels) {
		foreach my $user ($chan->nicks()) {
			my $nick = $user->{nick};
			my $addr = $user->{host};
			my $name = $user->{realname};
			$name =~ s/\002|\003(?:\d{1,2}(?:,\d{1,2})?)?|\017|\026|\037|\035//g;	# remove formatting
			$name = substr($name, 5) if (($chan->{server}{tag} =~ /^ircnet$/i) && (length($name) > 5)); # ircnet adds SID before real name
			my ($ident, $host) = split(/@/, $addr);
			my $data = ($fullhost ? "$nick\!$addr" : $nick);
			$data .= ':' . $chan->{server}{tag} if (lc($chan->{server}{tag}) ne lc($server->{tag}));
			$users{$data}++ if ($matchuser && ("$nick\!$addr" =~ /$re_pattern/i));
			$users{$data}++ if ($matchnick && ($nick =~ /$re_pattern/i));
			$users{$data}++ if ($matchident && ($ident =~ /$re_pattern/i));
			$users{$data}++ if ($matchhost && ($host =~ /$re_pattern/i));
			$users{$data}++ if ($matchname && ($name =~ /$re_pattern/i));
		}
	}
	if (scalar keys %users) {
		printformat(MSGLEVEL_CRAP, 'matchusers_nicks', $pattern, join(', ', sort { lc($a) cmp lc($b) } keys %users));
		printformat(MSGLEVEL_CRAP, 'matchusers_count', scalar(keys %users));
	} else {
		printformat(MSGLEVEL_CRAP, 'matchusers_no_matches', $pattern);
	}
}

sub cmd_help {
	my ($cmd, $server, $window) = @_;
	$cmd =~ s/^\s+|\s+$//g;
	if (lc($cmd) eq 'matchusers') {
		print CLIENTCRAP;
		print CLIENTCRAP 'MATCHUSERS [-a/n/i/h/r/f] <pattern> [channel]';
		print CLIENTCRAP;
		print CLIENTCRAP '   -a - match against nick!ident@host (default)';
		print CLIENTCRAP '   -n - match against nicks';
		print CLIENTCRAP '   -i - match against idents';
		print CLIENTCRAP '   -h - match against hosts';
		print CLIENTCRAP '   -r - match against real names (excluded from default search, use "-a -r")';
		print CLIENTCRAP '   -f - display full hostname';
		print CLIENTCRAP;
		print CLIENTCRAP 'Search for known users matching a pattern from all channels (status) or from active channel. You may also give channel name to search only there.';
		print CLIENTCRAP;
		print CLIENTCRAP 'Wildcards: * (zero or more characters), ? (one character), % (one digit), & (one alphabetic character)';
		print CLIENTCRAP;
		signal_stop();
	}
}

command_bind('help',		'cmd_help');
command_bind('matchusers',	'cmd_matchusers');
