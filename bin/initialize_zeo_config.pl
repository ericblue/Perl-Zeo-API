#!/usr/bin/perl

# ABSTRACT: Generate a ~/zeo.conf config for use by WebService::Zeo

use File::HomeDir;
use Data::Dumper;
use Term::ReadKey;
use MIME::Base64;

use strict;

sub prompt_for_input {

    my ( $input_prompt, $echo, $default_value ) = @_;

    $echo = 1 if !defined($echo);

    print "$input_prompt? ";
    ReadMode('noecho') if !$echo;
    chomp( my $input = ReadLine(0) );
    print "\n" if !$echo;
    ReadMode('restore');

    $input = $default_value if $input eq "";

    die "Input is required!" if length($input) < 1;

    return $input;

}

my $apikey   = prompt_for_input( "Enter your API Key",              1 );
my $website  = prompt_for_input( "Enter your Website URL",          1 );
my $username = prompt_for_input( "Enter your Zeo username (email)", 1 );
my $password = prompt_for_input( "Enter your Zeo password",         0 );
my $do_encode =
  prompt_for_input( "Encode your credentials in the config (Y|N)", 1, "y" );

my $config_file = File::HomeDir->my_home . '/zeo.conf';

my $config;

if ( $do_encode =~ /y|Y/ ) {
    my $encoded = encode_base64("$username:$password");
    chop $encoded;

    $config = {
        'apikey'        => $apikey,
        'referrer'      => $website,
        'authorization' => $encoded
    };
}
else {
    $config = {
        'apikey'   => $apikey,
        'referrer' => $website,
        'username' => $username,
        'password' => $password
    };
}

open( CONFIG, ">$config_file" )
  or die("Can't create zeo config for testing");
$Data::Dumper::Terse = 1;
print CONFIG Data::Dumper->Dump( [$config] );
close(CONFIG);

