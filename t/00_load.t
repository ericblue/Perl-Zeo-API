#!/usr/bin/perl

use Test::More qw(no_plan);

use FindBin qw($Bin);
use lib "$Bin/../lib";

use strict;

BEGIN {
    use_ok('WebService::Zeo');
}

