use strict;
use warnings;
use IO::Socket::INET;

{
    package Gearman::Client::Status;

    sub new {
        my $class = shift;
        my %args = @_==1 ? %{$_[0]} : @_;
        my $self = bless {
            host => '127.0.0.1',
            port => '7003',
            %args
        }, $class;
        my $sock = IO::Socket::INET->new(
            PeerAddr => $self->{host},
            PeerPort => $self->{port}
        ) // die "cannet open port: $!$@";
        $self->{sock} = $sock;
        return $self;
    }

    sub get_version {
        my ($self) = @_;
        my $sock = $self->{sock};
        print {$sock} "version\n";
        my $ver = <$sock>;
        return $ver;
    }

    # FUNCTION\tTOTAL\tRUNNING\tAVAILABLE_WORKERS
    sub get_stats {
        my ($self) = @_;
        my $word = "status\n";
        my $sock = $self->{sock};
        print {$sock} $word;
        my @cols;
        while (my $line = <$sock>) {
            last if $line eq ".\n";
            push @cols, [split /\s/, $line];
        }
        return wantarray ? @cols : \@cols;
    }

    # FD IP-ADDRESS CLIENT-ID : FUNCTION ...
    # 7 127.0.0.1 lywnwtelzjztcrbbemxnmtsgvkayxv : hoge
    sub get_workers {
        my ($self, ) = @_;
        my $word = "workers\n";
        my $sock = $self->{sock};
        print {$sock} $word;
        my @cols;
        while (my $line = <$sock>) {
            last if $line eq ".\n";
            if ($line =~ /^(\d+)\s+(\S+)\s+(\S+)\s+:\s*(.*)\n$/) {
                push @cols, [$1, $2, $3, $4];
            } else {
            warn "SKIP $line";
                last;
            }
        }
        return wantarray ? @cols : \@cols;
    }
}

my $host = $ENV{GEARMAN_STAT_HOST} || '127.0.0.1';
my $port = $ENV{GEARMAN_STAT_PORT} || 7003;

my $client = Gearman::Client::Status->new(host => $host, port => $port);

my $app = sub {
    warn "HOGE";

    my $html = <<'...';
<!doctype html>
<html>
<head>
    <title>Gearman Status</title>
    <style type='text/css'>
        body{ font-family: 'Trebuchet MS';color: #444;background: #f9f9f9;}
        h1 {background: #eee;border: 1px solid #ddd;padding: 3px;text-shadow: #ccc 1px 1px 0;color: #756857;text-transform:uppercase;}
        h2 {padding: 3px;text-shadow: #ccc 1px 1px 0;color: #ACA39C;text-transform:uppercase;border-bottom: 1px dotted #ddd;display: inline-block;}
        hr {color: transparent;}
        table{width: 100%;border: 1px solid #ddd;border-spacing:0px;}
        table th {border-bottom: 1px dotted #ddd;background: #eee;padding: 5px;font-size: 15px;text-shadow: #fff 1px 1px 0;}
        table td {text-align: center;padding: 5px;font-size: 13px;color: #444;text-shadow: #ccc 1px 1px 0;}
    </style>
</head>
<body>
    <h1>Gearman Server Status</h1>
...
    $html .= q{<div class="version">Server Version: } . $client->get_version() . "</div>\n";

    $html .= <<'...';
    <h2>Workers</h2>
    <table border='0'>
        <tr><th>File Descriptor</th><th>IP Address</th><th>Client ID</th><th>Function</th></tr>
...
    $client->get_version();
    for my $row ($client->get_workers()) {
        $html .= sprintf(qq{<tr><td>%d</td><td>%s</td><td>%s</td><td>%s</td></tr>\n}, @$row);
    }
    $html .= <<'...';
    </table>

    <h2>Status</h2>
    <table border='0'>
        <tr><th>Function</th><th>Total</th><th>Running</th><th>Available Workers</th></tr>
...
    for my $row ($client->get_stats()) {
        $html .= sprintf(qq{<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n}, @$row);
    }
    $html .= <<'...';
    </table>
</body>
</html>
...

    return [
        200,
        [
            'Content-Type'   => 'text/html; charset=utf-8',
            'Content-Length' => length($html)
        ],
        [$html]
    ];
};

