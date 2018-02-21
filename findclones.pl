#######################################
##  Clone detector by wilk/xorandor  ##
#######################################
#
# /findclones [-a/h/i/p/u/l] [channel]
#  Detects ident, host, proxy and ident@host clones on provided
#   channel, otherwise seeks them globally (status) or on active
#   channel.
#  Supports multiple networks (appends network tag).
#
#  Options:
#   -a = find all below types of clones (default)
#   -h = find host clones (*!*@host)
#   -i = find ident clones (*!ident@*)
#   -p = find proxy clones (excluded from default search)
#   -u = find user clones (*!ident@host)
#   -l = loose idents (drops prefixes and uses *ident)
#
#####
#
# v1.0 (20180219)
#  - extracted from my old script and made it public
#

use strict;
use warnings;
use vars qw($VERSION %IRSSI);
use Irssi qw(theme_register command_bind printformat signal_stop channels);

$VERSION = '1.0';
%IRSSI = (
	name		=> 'findclones',
	description	=> 'Detects ident, host, proxy, ident@host clones',
	authors		=> 'wilk',
	contact		=> 'wilk @ IRCnet',
	license		=> 'GNU GPL v2 or any later version',
	changed		=> '19.02.2018',
	url			=> 'https://scripts.irssi.org'
);

Irssi::theme_register([
	'findclones_host',			'Host clones: $0',
	'findclones_ident',			'Ident clones: $0',
	'findclones_proxy',			'Proxy clones: $0',
	'findclones_user',			'User clones: $0',
	'findclones_count',			'Total clones: $0',
	'findclones_no_clones',		'No clones detected',
	'findclones_no_channel',	'No such channel is joined',
]);

sub cmd_findclones {
	my ($args, $server, $channel) = @_;
	$args =~ s/^\s+|\s+$//g;
	my ($id, $looseidents, $hostclones, $identclones, $proxyclones, $userclones) = (0) x 6;
	my $showall = 1;
	my @args = split(/ /, lc $args);
	if (grep { $_ eq '-l' } @args) { $looseidents = 1; $id++; }
	if (grep { $_ eq '-h' } @args) { $hostclones = 1; $showall = 0; $id++; }
	if (grep { $_ eq '-i' } @args) { $identclones = 1; $showall = 0; $id++; }
	if (grep { $_ eq '-p' } @args) { $proxyclones = 1; $showall = 0; $id++; }
	if (grep { $_ eq '-u' } @args) { $userclones = 1; $showall = 0; $id++; }
	if (grep { $_ eq '-a' } @args) { $showall = 1; $id++; }
	my $forchan = $args[$id] // '';
	my $chan = ($forchan ne '') ? $server->channel_find($forchan) : undef;
	my @channels;
	if (defined $chan) {
		push(@channels, $chan);
	} elsif ($forchan ne '') {
		printformat(MSGLEVEL_CRAP, 'findclones_no_channel');
		return;
	} elsif ($channel && ($channel->{type} eq 'CHANNEL')) {
		push(@channels, $channel);
	} else {
		@channels = channels();
	}
	my (%hclones, %iclones, %uclones, %pclones);
	foreach my $chan (@channels) {
		foreach my $user ($chan->nicks()) {
			my $nick = $user->{nick};
			my ($ident, $host) = split(/@/, $user->{host});
			my $proxy = ($ident =~/^[\^~+=\-]/) ? '*!*@' : ''; # '*!' . $ident . '@';
			#   = full UNIX		+ = rest UNIX
			# ^ = full OTHER	= = rest OTHER
			# ~ = full none		- = rest none
			if ($proxy ne '') {
				if ($host =~ /^((\d+\.){3})\d+$/) {
					$proxy .= $1 . '*'; # XX.XX.XX.*
				} elsif ($host =~ /^((?:[0-9a-f]+:){4})(?:[0-9a-f]+:){3}[0-9a-f]+$/i) {
					$proxy .= $1 . '*'; # XXXX:XXXX:XXXX:XXXX:*
				#} elsif ($host =~ /.+?(\.[^.]+?\.[^.]+?)$/) {
				} elsif ($host =~ /^[^.]+?(\.[^.]+?\..+)$/) {
					$proxy .= '*' . $1; # *.domain.tld
				} else {
					$proxy = '';
				}
			}
			if ($looseidents) {
				$ident =~ s/^[\^~+=\-]//;
				$ident = '*' . $ident;
			}
			$nick .= (lc($chan->{server}{tag}) ne lc($server->{tag})) ? ':' . $chan->{server}{tag} : '';
			push(@{$pclones{$proxy}}, $nick) if ($proxyclones && ($proxy ne ''));
			push(@{$hclones{'*!*@' . $host}}, $nick) if ($hostclones || $showall);
			push(@{$iclones{'*!' . $ident . '@*'}}, $nick) if ($identclones || $showall);
			push(@{$uclones{'*!' . $ident . '@' . $host}}, $nick) if ($userclones || $showall);
		}
	}
	my $clones = 0;
	$clones += print_clones('findclones_host', \%hclones);
	$clones += print_clones('findclones_ident', \%iclones);
	$clones += print_clones('findclones_proxy', \%pclones);
	$clones += print_clones('findclones_user', \%uclones);
	printformat(MSGLEVEL_CRAP, 'findclones_no_clones') if (!$clones);
}

sub print_clones {
	my ($format, $clones) = @_;
	my $count = 0;
	foreach my $clone (sort { lc($a) cmp lc($b) } keys %$clones) {
		if (@{$$clones{$clone}} > 1) {
			my @nicks = sort { lc($a) cmp lc($b) } keys %{ { map { $_ => 1 } @{$$clones{$clone}} } };
			if (@nicks > 1) {
				printformat(MSGLEVEL_CRAP, $format, $clone . ' (' . join(', ', @nicks) . ')');
				$count++;
			}
		}
	}
	return $count;
}

sub cmd_help {
	my ($cmd, $server, $window) = @_;
	$cmd =~ s/^\s+|\s+$//g;
	if (lc($cmd) eq 'findclones') {
		print CLIENTCRAP;
		print CLIENTCRAP 'FINDCLONES [-a/h/i/p/u/l] [channel]';
		print CLIENTCRAP;
		print CLIENTCRAP '   -a = find all below types of clones (default)';
		print CLIENTCRAP '   -h = find host clones (*!*@host)';
		print CLIENTCRAP '   -i = find ident clones (*!ident@*)';
		print CLIENTCRAP '   -p = find proxy clones (excluded from default search, use "-a -p")';
		print CLIENTCRAP '   -u = find user clones (*!ident@host)';
		print CLIENTCRAP '   -l = loose idents (drops prefixes and uses "*ident"; for -i and -u)';
		print CLIENTCRAP;
		print CLIENTCRAP 'Detects ident, host, proxy and ident@host clones on provided channel, otherwise seeks them globally (status) or on active channel.';
		print CLIENTCRAP;
		print CLIENTCRAP 'Connection is considered as a proxy for identless users. Then ident is dropped and host is reduced: IPv4 by last octet (X.X.X.* = /24), hosts by first segment (*.domain.tld), IPv6 by last four hextets (X:X:X:X:* = /64). This is based on Psotnic bot behaviour.';
		print CLIENTCRAP;
		signal_stop();
	}
}

command_bind('help',		'cmd_help');
command_bind('findclones',	'cmd_findclones');
