#!/usr/bin/perl -w

# Copyright (c) 2009 by Steve Fink
# License: BSD

our $VERSION = "1.1";

use strict;
use Getopt::Long;
use IO::Socket;
use Time::HiRes qw(sleep);
use Term::ReadKey;

my $server = "mail";
my $trouble = "inbox/Trouble";
my $copy_only;
my $no_writes;
my $login;
my $password;
my $box;
my $verbose = 0;
my $force;

GetOptions("copy-only|copy|c!" => \$copy_only,
	   "no-writes|dry-run|n!" => \$no_writes,
	   "mailserver|server|s=s" => \$server,
	   "username|user|login|u=s" => \$login,
	   "password|p=s" => \$password,
     "box|b=s" => \$box,
	   "verbose|v!" => \$verbose,
	   "quiet|q!" => sub { $verbose = 0; },
	   "force|f!" => \$force,
	   "trouble-mailbox-name|trouble|T" => \$trouble, # Capital T
           "help|h!" => sub { usage(0); },
	   )
  or do { warn "Bad arguments\n"; usage(1); };

sub usage {
    my ($status) = @_;

    print <<"END";
Usage: $0 [options...]
  --mailserver=HOST, -s HOST  Hostname of mail server (default: 'mail')
  --username=USER, -u USER    Username on mail server
  --password=PASS, -p PASS    Password on mail server
  --box, -b BOX               Mailbox Folder to clean (defaults to Inbox and Deleted Items)
  --verbose, -v               Lots of extra output
  --quiet, -q                 Minimal output (default)
  --force, -f                 Do not ask before moving and deleting mail
  --help, -h                  Display this message

Note that only unencrypted IMAP connections are currently supported.
END

    exit $status;
}

# The session tag used for talking to the IMAP server.
my $TAG = "x";

# Statistics
my ($fetches, $message_fetches) = (0, 0);

if (! defined $login) {
  print "Enter login> ";
  chomp($login = <STDIN>);
}

if (! defined $password) {
  ReadMode('noecho');
  print "Enter password> ";
  chomp($password = ReadLine(0));
  ReadMode('restore');
  print "\n";
}

my $sock = IO::Socket::INET->new(Protocol => 'tcp',
				 PeerAddr => "$server:imap")
  or die "failed to connect to mail server '$server'. Use the -s option to select a different one.\n";
$sock->blocking(0);

# Log in
send_command($sock, "LOGIN \"$login\" \"$password\"");
check_response($sock);

if (! defined $box) {
  # clean inbox and deleted items
  clean_box("inbox");
  clean_box("deleted items");
  clean_box("trash");
} else {
  clean_box($box);
}

######################################################################

sub clean_box {
  my ($thebox) = @_;
  # Select the inbox and get the message count
  send_command($sock, "SELECT \"".join(" ", $thebox).join(" ", "\""));

  print "Scanning for bad messages in '$thebox'...\n";
  
  my $data = check_response($sock);
  my ($num_messages) = $data =~ /\* (\d+) EXISTS/
    or die "Cannot find number of messages\n";
  
  # Find the bad messages
  my @missing = find_bad($sock, 1, $num_messages);
  if (@missing == 0) {
    print "All $num_messages look ok. No bad messages found.\n";
  } else {
    print "Bad message IDs: " . join(" ", map { "#$_" } @missing) . "\n";
    print "Found with $fetches fetches of $message_fetches messages\n"
      if $verbose;
    
    verify("Delete messages from inbox?") unless $force;
    send_command($sock, "STORE ".join(",", @missing)." FLAGS \\Deleted");
    check_response($sock);
    
    verify("Compact inbox (expunge deleted messages)?") unless $force;
    send_command($sock, "EXPUNGE");
    check_response($sock);
  }
}

sub verify {
  my ($msg) = @_;
  print "$msg ";
  my $response = <STDIN>;
  chomp($response);
  exit 0 if $response !~ /^y/i;
}

sub check_response {
  my ($sock) = @_;
  my $data = get_response($sock, $TAG);
  print "Response: $data\n" if $verbose;
  if ($data !~ /^$TAG OK/m) {
      die "Command failed\n\nVerbose output:\n$data\n";
  }
  return $data;
}

sub send_command {
  my ($socket, $command) = @_;
  if ($verbose) {
    print ("Command: $command\n") unless $command =~ m/LOGIN/;
  }
  $socket->syswrite("$TAG $command\r\n");
}

# I can't remember why I had to do nonblocking reads...
sub get_response {
  my ($socket) = @_;

  my $data = '';
  while (1) {
    my $n = $socket->sysread($data, 4096, length($data));
    if (! defined $n) {
      if ($! =~ /would block|temporarily unavailable/) {
	sleep(0.1);
      } else {
	die "Error reading socket: $!";
      }
    } elsif ($n == 0) {
      return $data;
    } else {
      return $data if $data =~ /^$TAG .*\n/m;
    }
  }
}

# Funky routine to identify the list of bad messages, taking into
# account some rather odd behavior I have experienced in talking
# to my mail server: when I FETCH a range of messages that includes
# some bad ones, it usually returns all valid messages in that range,
# but sometimes some or all of the valid messages are missing.
#
# So this routine treats any message id returned by FETCH as "definitely
# good", and anything missing as "possibly bad". A message is only
# determined to be "definitely bad" if a FETCH for its single message
# number fails (it'll return "NO" instead of "OK", although I just check
# for the absence of "NO".)
#
# Note that this is a little more complicated than it needs to be, because
# it is pretty slow unless you optimize it to make some use of the
# "definitely good" responses.
#
# It's also crazy stupid: I require the FETCH of an entire mailbox to
# fit into memory, but I take pains to not require a simple array of
# valid ids to fit into the same memory. It would have simplified
# things if I hadn't worried about it. Gimme a break: I spent about 2
# hours total on this script, and premature optimization, like other
# evils, is fun!
#
sub find_bad {
  my ($sock, $first, $last) = @_;

  my $orig = "$first .. $last";
  $::INDENT .= '';
  print "$::INDENT$orig\n" if $verbose;

  return () if $first > $last;

  send_command($sock, "FETCH $first:$last FAST");
  ++$fetches;
  $message_fetches += $last - $first + 1;

  my $data = get_response($sock, $TAG);
  if ($data =~ /^$TAG OK/m) {
    return (); # Nothing bad in this range
  }

  if ($first == $last) {
    print $::INDENT . "SINGLE: $orig -> $first\n" if $verbose;
    return ($first);
  }

  # Move $first forward through valid messages
  while ($data =~ /^\* (\d+) FETCH/mg) {
    last if $1 != $first;
    ++$first;
  }

  # Back up $last to the final valid message, which is a little
  # difficult to determine: watch for consecutive runs of good
  # messages, and if the final good message is $last, then back up
  # $last to just before the beginning of that final run. Otherwise,
  # leave $last alone; we did not find a valid message.
  my $good = [ 0, -1 ];
  while ($data =~ /^\* (\d+) FETCH/mg) {
    if ($1 != $good->[1] + 1) {
      $good = [ $1, $1 ]; # Reset to a new chunk of adjacent good messages
    } else {
      $good->[1] = $1; # Just advance the end of the currently good chunk
    }
  }
  if ($good->[1] == $last) {
    $last = $good->[0] - 1;
  }

  # Binary search, sort of: find all bad messages, not just one, and
  # the only way to confirm something as being bad is to request just
  # that one message (because the server might not return any good
  # messages if even one bad message is in the requested range.)
  my $next = $first + 1;
  my $mid = int(($next + $last) / 2);

  $::INDENT .= "  ";
  my @bad = (find_bad($sock, $first, $first),
	     find_bad($sock, $next, $mid),
	     find_bad($sock, $mid + 1, $last - 1));
  push @bad, find_bad($sock, $last, $last) unless $first >= $last;
  chop($::INDENT);
  chop($::INDENT);
  print $::INDENT . "RESULT: $orig -> @bad\n" if $verbose;
  return @bad;
}
