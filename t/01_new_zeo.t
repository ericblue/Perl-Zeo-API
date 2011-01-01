#!/usr/bin/perl

use Test::More qw(no_plan);
use Test::Exception;
use Data::Dumper;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use strict;

my $temp_config = "/tmp/zeo.conf";

BEGIN {
    use_ok('WebService::Zeo');
}

# TODO Create additional tests for requests - considering mocking LWP to read json locally

sub create_config {

    my $config = {
        'apikey' => '05F5A0711F085DDD507BF584F2F54875',
        'base_zeo_url' =>
          'http://api-staging.myzeo.com:8080/zeows/api/v1/json/sleeperService',
        'referrer' => 'http://www.mywebsite.com',
        'username' => 'myzeotest@gmail.com',
        'password' => 'foobar',
    };
    
    open(CONFIG,">$temp_config") or die ("Can't create zeo config for testing");
    $Data::Dumper::Terse = 1;
    print CONFIG Data::Dumper->Dump([$config]);
    close(CONFIG); 

}

sub delete_config {
    unlink($temp_config);
}

ok(
    WebService::Zeo->new(
        username => 'user@domain.com',
        password => 'foobar',
        apikey   => 'apikey'
    ),
    'new() with required parameters'
);

dies_ok(
    sub {
        WebService::Zeo->new(
            username => 'user@domain.com',
            password => 'foobar'
          )

    },
    'new() without apikey throws exception'
);

create_config();

ok(
    WebService::Zeo->new(
        config   => $temp_config
    ),
    'new() with valid config'
);

delete_config();

dies_ok(
    sub {
        WebService::Zeo->new( config => '/bad/config/path' )

    },
    'new() with invalid config throws exception'
);
