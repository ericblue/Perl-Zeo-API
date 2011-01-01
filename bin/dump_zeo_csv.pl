#!/usr/bin/perl

# ABSTRACT: Write last 7 days of recorded sleep data to CSV

use WebService::Zeo;
use Text::CSV;
use File::HomeDir;
use Carp;

use strict;

sub create_date_string {

    my ($d) = @_;

    my $date = $d->{year} . "-" . $d->{month} . "-" . $d->{day};

    # Create date string only if HH:MM:SS aren't present
    if ( !exists $d->{hour} ) {
        return $date;
    }
    else {
        # Add leading zeros to correct JSON output
        my $time =
            sprintf( "%02d", $d->{hour} ) . ":"
          . sprintf( "%02d", $d->{minute} ) . ":"
          . sprintf( "%02d", $d->{second} );

        return "$date $time";
    }

}

my $config_file = File::HomeDir->my_home . '/zeo.conf';
my $zeo = eval { new WebService::Zeo( config => $config_file ) }
  or die("Error encountered: $@");

my @dates = $zeo->get_all_dates_with_sleep_data();

my $total_days = 7;
my $days_saved = 0;

my @header = qw{
  DATE
  ZQ_SCORE
  TIME_TO_Z_MIN
  TIME_IN_LIGHT_MIN
  TIME_IN_REM_MIN
  TIME_IN_DEEP_MIN
  AWAKENINGS
  TOTAL_Z_MIN
  BED_TIME
  RISE_TIME
  MORNING_FEEL
};

my $csv = Text::CSV->new( { binary => 1, eol => "\n" } );
$csv->print(*STDOUT, \@header );

foreach ( reverse(@dates) ) {

    last if $days_saved == $total_days;
    
    my $date_string = create_date_string($_);

    my $sleep = $zeo->get_sleep_record_for_date($date_string);

    my @row = (
        $date_string,
        $sleep->{zq},
        $sleep->{timeToZ},
        $sleep->{timeInLight},
        $sleep->{timeInRem},
        $sleep->{timeInDeep},
        $sleep->{awakenings},
        $sleep->{totalZ},
        create_date_string( $sleep->{bedTime} ),
        create_date_string( $sleep->{riseTime} ),
        $sleep->{morningFeel},
    );
    
    $csv->print( *STDOUT, \@row );

    $days_saved++;

}
