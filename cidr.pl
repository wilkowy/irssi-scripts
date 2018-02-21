########################################
##  CIDR calculator by wilk/xorandor  ##
########################################
#
# /cidr <ip>/<bits>
# /cidr <ip>/<mask>
# /cidr <ip> <ip>
#  Converts CIDR and IP with mask to IP range, fits IP range to CIDR.
#
#####
#
# v1.0 (20180219)
#  - extracted from my old script and made it public
#
#####
#
# todo: ipv6 support
#

use strict;
use warnings;
use vars qw($VERSION %IRSSI);
use Irssi qw(theme_register command_bind printformat signal_stop);

$VERSION = '1.0';
%IRSSI = (
	name		=> 'cidr',
	description	=> 'Converts between CIDR, IP with mask and IP range',
	authors		=> 'wilk',
	contact		=> 'wilk @ IRCnet',
	license		=> 'GNU GPL v2 or any later version',
	changed		=> '19.02.2018',
	url			=> 'https://scripts.irssi.org'
);

Irssi::theme_register([
	'cidr_to_range',		'$0 -> %_$1 - $2%_ = $3/$4',
	'cidr_to_range_circa',	'$0 -> %_$1 - $2%_ ~ $3/$4 = $5 - $6',
	'cidr_to_cidr',			'$0 - $1 -> %_$2/$3%_ = $4/$5',
	'cidr_to_cidr_circa',	'$0 - $1 ~> %_$2/$3%_ = $4 - $5 = $6/$7',
	'cidr_invalid_ip',		'Invalid IP',
	'cidr_invalid_bits',	'Invalid CIDR bits',
	'cidr_invalid_mask',	'Invalid IP mask',
]);

sub cmd_cidr {
	my ($arg1, $arg2, $rest) = split(/ /, shift);
	$arg2 = $rest if (defined($arg2) && ($arg2 eq '-')); # case: /cidr ip1 - ip2 (optional "-")
	if (index($arg1, '-') != -1) {
		($arg1, $arg2) = split(/\-/, $arg1); # case: /cidr ip1-ip2
	}
	printformat(MSGLEVEL_CRAP, 'cidr_invalid_ip'), return if (!defined($arg1) || ($arg1 eq ''));
	if (index($arg1, '/') != -1) { # /cidr ip/bits OR /cidr ip/mask
		my ($ip, $bits) = split(/\//, $arg1);
		printformat(MSGLEVEL_CRAP, 'cidr_invalid_ip'), return if (!validip($ip));
		if ($bits =~ /^\d+$/) { # /cidr ip/bits
			printformat(MSGLEVEL_CRAP, 'cidr_invalid_bits'), return if (($bits < 0) || ($bits > 32));
			my ($ip_l, $ip_h, $mask) = cidr2range($ip, $bits);
			printformat(MSGLEVEL_CRAP, 'cidr_to_range', $arg1, $ip_l, $ip_h, $ip, $mask);
		} else { # /cidr ip/mask
			my $mask = $bits;
			printformat(MSGLEVEL_CRAP, 'cidr_invalid_mask'), return if (!validip($mask));
			my ($ip_l, $ip_h, $bits, $long_ip_l, $long_ip_h) = mask2range($ip, $mask);
			my ($ip2_l, $ip2_h, undef, $long_ip2_l, $long_ip2_h) = cidr2range($ip, $bits);
			if (($long_ip_l == $long_ip2_l) && ($long_ip_h == $long_ip2_h)) {
				printformat(MSGLEVEL_CRAP, 'cidr_to_range', $arg1, $ip_l, $ip_h, $ip_l, $bits);
			} else {
				printformat(MSGLEVEL_CRAP, 'cidr_to_range_circa', $arg1, $ip_l, $ip_h, $ip_l, $bits, $ip2_l, $ip2_h);
			}
		}
	} else { # /cidr ip1 ip2
		my ($ip1, $ip2) = ($arg1, $arg2);
		printformat(MSGLEVEL_CRAP, 'cidr_invalid_ip'), return if (!validip($ip1) || !validip($ip2));
		my (undef, $bits, $long_ip_l, $long_ip_h) = range2cidr($ip1, $ip2);
		my ($ip2_l, $ip2_h, $mask, $long_ip2_l, $long_ip2_h) = cidr2range($ip1, $bits);
		if (($long_ip_l == $long_ip2_l) && ($long_ip_h == $long_ip2_h)) {
			printformat(MSGLEVEL_CRAP, 'cidr_to_cidr', $ip1, $ip2, $ip2_l, $bits, $ip2_l, $mask);
		} else {
			printformat(MSGLEVEL_CRAP, 'cidr_to_cidr_circa', $ip1, $ip2, $ip2_l, $bits, $ip2_l, $ip2_h, $ip2_l, $mask);
		}
	}
}

sub validip {
	my $ip = shift;
	return 0 if (!defined($ip) || ($ip eq ''));
	if (index($ip, ':') != -1) {
		return 0; # ipv6 - todo
		#return 0 if (split(/::/, $ip) > 2);
		#my @hextets = split(/:/, $ip);
		#return 0 if (@hextets > 8);
		# todo: expand ::
		#return 0 if (@hextets != 8);
		#foreach my $hextet (@hextets) {
		#	return 0 if ((substr($hextet, 0, 1) eq '0') && (length($hextet) > 1));
		#	return 0 if ($hextet =~ /[^0-9a-f]/);
		#}
	} else {
		my @octets = split(/\./, $ip);
		return 0 if (@octets != 4);
		return 0 if (grep { ($_ !~ /^\d+$/) || ($_ > 255) || ($_ < 0) } @octets);
	}
	return 1;
}

sub longip {
	my $ip = shift;
	return -1 if (!defined($ip) || ($ip eq ''));
	return -1 if (index($ip, ':') != -1); # nope, no ipv6
	my @octets = split(/\./, $ip);
	if (@octets == 1) {
		return -1 if ($ip !~ /^\d+$/);
		my $hip = sprintf('%08x', $ip);
		return sprintf('%d.%d.%d.%d', hex(substr($hip, 0, 2)), hex(substr($hip, 2, 2)), hex(substr($hip, 4, 2)), hex(substr($hip, 6, 2)));
		# return inet_ntoa(pack('N*', $ip));
	} elsif (validip($ip)) {
		return (((($octets[0] * 256) + $octets[1]) * 256 + $octets[2]) * 256 + $octets[3]);
		# return unpack('l*', pack('l*', unpack('N*', inet_aton($ip))));
	} else {
		return -1;
	}
}

sub cidr2range {
	my ($ip, $bits) = @_;
	my $long_mask = (0xffffffff << (32 - $bits)) & 0xffffffff;
	my $long_ip_l = longip($ip) & $long_mask;
	my $long_ip_h = $long_ip_l | (~$long_mask & 0xffffffff);
	return (longip($long_ip_l), longip($long_ip_h), longip($long_mask), $long_ip_l, $long_ip_h);
}

sub mask2range {
	my ($ip, $mask) = @_;
	my $long_ip_l = longip($ip) & longip($mask);
	my $long_ip_h = $long_ip_l | (~longip($mask) & 0xffffffff);
	my $diff = $long_ip_h - $long_ip_l;
	my $bits = 0;
	while ($diff > 0) {
		$bits++;
		$diff >>= 1;
	}
	return (longip($long_ip_l), longip($long_ip_h), 32 - $bits, $long_ip_l, $long_ip_h);
}

sub range2cidr {
	my ($ip_l, $ip_h) = @_;
	my ($long_ip_l, $long_ip_h) = (longip($ip_l), longip($ip_h));
	my ($tlipl, $tliph) = ($long_ip_l, $long_ip_h);
	my $bits = 0;
	while (($tlipl & 0x80000000) == ($tliph & 0x80000000)) {
		$bits++;
		last if ($bits == 32);
		$tlipl <<= 1;	$tliph <<= 1;
	}
	return ($ip_l, $bits, $long_ip_l, $long_ip_h);
}

sub cmd_help {
	my ($cmd, $server, $window) = @_;
	$cmd =~ s/^\s+|\s+$//g;
	if (lc($cmd) eq 'cidr') {
		print CLIENTCRAP;
		print CLIENTCRAP 'CIDR <ip>/<bits>';
		print CLIENTCRAP 'CIDR <ip>/<mask>';
		print CLIENTCRAP 'CIDR <ip> <ip>';
		print CLIENTCRAP;
		print CLIENTCRAP 'Converts CIDR and IP with mask to IP range, fits IP range to CIDR.';
		print CLIENTCRAP;
		signal_stop();
	}
}

command_bind('help',	'cmd_help');
command_bind('cidr',	'cmd_cidr');
