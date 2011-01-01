# $Id: Zeo.pm,v 1.3 2011-01-01 09:17:29 ericblue76 Exp $
#
# Author:       Eric Blue - ericblue76@gmail.com
# Project:      Perl Zeo API
# Url:          http://eric-blue.com
#

# ABSTRACT: OO Perl API used to fetch sleep data from myzeo.com

package WebService::Zeo;

use JSON;
use LWP::UserAgent;
use HTTP::Request;
use Crypt::SSLeay;
use MIME::Base64;
use Data::Dumper;
use Log::Log4perl qw(:easy);

use POSIX;
use Carp;
use strict;

#################################################################
# Title         : new (public)
# Usage         : my $zeo = WebService::Zeo->new(parx => 'valy');
# Purpose       : Constructor
# Parameters    : username, password, apikey, config, etc.
# Returns       : Blessed class

sub new {

    my $class  = shift;
    my $self   = {};
    my %params = @_;

    bless $self, $class;

    # Load config if parameter exists
    my $config = $self->_load_zeo_config( $params{config} )
      if ( defined $params{config} );

    # Set class fields from either config file or constructor parameters
    my @init_params =
      qw[apikey referrer username password base_zeo_url authorization logger_config];
    foreach my $p (@init_params) {
        my $field_name = "_" . $p;
        $self->{$field_name} =
          defined $config->{$p} ? $config->{$p} : $params{$p};
    }

# If the authorization parameter is defined, decode to extract username and password
    if ( defined $self->{_authorization} ) {
        ( $self->{_username}, $self->{_password} ) =
          split( /:/, decode_base64( $self->{_authorization} ) );
    }

    # Check fields that must be define for initialization to succeed
    my @required_fields = qw[apikey username password];
    foreach my $f (@required_fields) {
        my $field_name = "_" . $f;
        croak
          "Field $f must be set via config or as an initialization parameter!"
          if !defined( $self->{$field_name} );
    }

    # Initialize LWP browser
    $self->{_browser} = LWP::UserAgent->new();
    $self->{_browser}->agent("Zeo Perl API/1.0");
    $self->{_base_zeo_url} =
      "https://api.myzeo.com:8443/zeows/api/v1/json/sleeperService"
      if !defined $self->{_base_zeo_url};

    # Initialize Logger
    if (    ( defined $self->{_logger_config} )
        and ( -e $self->{_logger_config} ) )
    {
        Log::Log4perl->init( $self->{_logger_config} );
    }
    else {
        Log::Log4perl->easy_init($ERROR);
    }
    $self->{_logger} = get_logger();

    # TODO Investigate using Moose for modernizing OO syntax

    $self;
}

#################################################################
# Title         : _load_zeo_config (private)
# Usage         : $self->_load_zeo_config($filename)
# Purpose       : Load config file from disk (Perl variable format)
# Parameters    : Filename = path to zeo.conf
# Returns       : evaled hashref with config values

sub _load_zeo_config {

    my $self = shift;
    my ($filename) = @_;

    $/ = "";
    open( CONFIG, "$filename" ) or croak "Can't open config $filename!";
    my $config_file = <CONFIG>;
    close(CONFIG);
    undef $/;

    my $config = eval($config_file) or croak "Invalid config file format!";

    return $config;

}

#################################################################
# Title         : _request_json (private)
# Usage         : $self->_request_json($method, $params)
# Purpose       : Request / serialize JSON and check for errors
# Parameters    : method = [Remote method name defined by API]
#                 params = [Parameters (as hashref) for method]
# Returns       : JSON key 'response'

sub _request_json {

    my $self = shift;
    my ( $method, $params ) = @_;

    $self->{_logger}->info("Calling method $method");
    my $url = $self->{_base_zeo_url} . "/" . $method . "?key=$self->{_apikey}&";

    # Set optional query string params required for the particular method
    $url .= join '&', map { "$_=$params->{$_}" } keys %{$params};

    my $json = $self->_request_http($url);
    $self->{_logger}->debug("json = $json");

    my $response = from_json($json);

    my $error = $response->{response}->{errMsg};
    if ( defined($error) ) {
        croak "Method $method return error (\"$error\")";
    }

    return $response->{response};

}

#################################################################
# Title         : _request_http (private)
# Usage         : $self->_request_http($url)
# Purpose       : Build URL based on method and JSON
# Parameters    : url = [Base URL + method + query string params]
#                 date = YYYY-MM-DD
# Returns       : JSON string

sub _request_http {

    my ( $self, $url ) = @_;

    $self->{_logger}->debug("URL = $url");

    my $request = new HTTP::Request 'GET', $url;
    $request->referer( $self->{_referrer} );
    $request->authorization_basic( $self->{_username}, $self->{_password} );
    my $response = $self->{_browser}->request($request);
    $self->{_logger}->debug( "Response = " . Dumper $response);

    if ( $response->code == 401 ) {
        croak "Invalid username or password (HTTP status = 401)!";
    }

    if ( !$response->is_success ) {
        $self->{_logger}
          ->info( "HTTP status = ", Dumper( $response->status_line ) );
        die "Couldn't get data; reason = HTTP status (", $response->code, ")!";
    }

    return $response->content;

}

#################################################################
# Title         : _check_date_format (private)
# Usage         : $self->_check_date_format($date)
# Purpose       : Verify valid date format is supplied
# Parameters    : date
# Returns       : 1 (true) ; croak on error

sub _check_date_format {

    my $self = shift;
    my ($date) = @_;

    # Uses ISO 8601 format (YYYY-MM-DD)

    if ( $date !~ /\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|30|31)/ ) {
        croak "Invalid date format [$date].  Expected (YYYY-MM-DD)";
    }

    return 1;
}

#################################################################
# Title         : _get_date (private)
# Usage         : $self->_get_date()
# Purpose       : Returns default date for methods where date
#                 parameter is not supplied; Defaults to today
# Parameters    : n/a
# Returns       : Date string (format = YYYY-MM-DD)

sub _get_date {

    my $self = shift;

    # Default to today's date
    my $date = strftime( "%F", localtime );

    return $date;

}

sub get_overall_average_zq_score {

    my $self = shift;

    my $result = $self->_request_json("getOverallAverageZQScore");
    return $result->{value};

}

sub get_overall_average_day_feel_score {

    my $self = shift;

    my $result = $self->_request_json("getOverallAverageDayFeelScore");
    return $result->{value};

}

sub get_overall_average_morning_feel_score {

    my $self = shift;

    my $result = $self->_request_json("getOverallAverageMorningFeelScore");
    return $result->{value};

}

sub get_overall_average_sleep_stealer_score {

    my $self = shift;

    my $result = $self->_request_json("getOverallAverageSleepStealerScore");
    return $result->{value};

}

sub get_all_dates_with_sleep_data {

    my $self = shift;

    my $result = $self->_request_json("getAllDatesWithSleepData");

    my @dates = [];
    @dates = @{ $result->{dateList}->{date} }
      if ref( $result->{dateList} ) eq "HASH";

    return @dates;
}

sub get_dates_with_sleep_data_in_range {

    my $self = shift;
    my ( $date_from, $date_to ) = @_;

    if ( ( !defined $date_from ) || ( !defined $date_to ) ) {
        croak "Date range values must be defined!";
    }

    my $result = $self->_request_json( "getDatesWithSleepDataInRange",
        { dateFrom => $date_from, dateTo => $date_to } );

    my @dates = [];
    @dates = @{ $result->{dateList}->{date} }
      if ref( $result->{dateList} ) eq "HASH";

    return @dates;
}

sub get_sleep_stats_for_date {

    my $self = shift;
    my ($date) = @_;

    defined $date ? $self->_check_date_format($date) : $date =
      $self->_get_date();

    my $result =
      $self->_request_json( "getSleepStatsForDate", { date => $date } );

    return $result->{sleepStats};

}

sub get_sleep_record_for_date {

    my $self = shift;
    my ($date) = @_;

    defined $date ? $self->_check_date_format($date) : $date =
      $self->_get_date();

    my $result =
      $self->_request_json( "getSleepRecordForDate", { date => $date } );

    return $result->{sleepRecord};

}

sub get_previous_sleep_stats {

    my $self = shift;
    my ($date) = @_;

    defined $date ? $self->_check_date_format($date) : $date =
      $self->_get_date();

    my $result =
      $self->_request_json( "getPreviousSleepStats", { date => $date } );

    return $result->{sleepStats};

}

sub get_previous_sleep_record {

    my $self = shift;
    my ($date) = @_;

    defined $date ? $self->_check_date_format($date) : $date =
      $self->_get_date();

    my $result =
      $self->_request_json( "getPreviousSleepRecord", { date => $date } );

    return $result->{sleepRecord};

}

sub get_next_sleep_stats {

    my $self = shift;
    my ($date) = @_;

    defined $date ? $self->_check_date_format($date) : $date =
      $self->_get_date();

    my $result = $self->_request_json( "getNextSleepStats", { date => $date } );

    return $result->{sleepStats};

}

sub get_next_sleep_record {

    my $self = shift;
    my ($date) = @_;

    defined $date ? $self->_check_date_format($date) : $date =
      $self->_get_date();

    my $result =
      $self->_request_json( "getNextSleepRecord", { date => $date } );

    return $result->{sleepRecord};

}

sub get_earliest_sleep_stats {

    my $self = shift;
    my ($date) = @_;

    defined $date ? $self->_check_date_format($date) : $date =
      $self->_get_date();

    my $result =
      $self->_request_json( "getEarliestSleepStats", { date => $date } );

    return $result->{sleepStats};

}

sub get_earliest_sleep_record {

    my $self = shift;
    my ($date) = @_;

    defined $date ? $self->_check_date_format($date) : $date =
      $self->_get_date();

    my $result =
      $self->_request_json( "getEarliestSleepRecord", { date => $date } );

    return $result->{sleepRecord};

}

sub getLatestSleepStats {

    my $self = shift;
    my ($date) = @_;

    defined $date ? $self->_check_date_format($date) : $date =
      $self->_get_date();

    my $result =
      $self->_request_json( "getLatestSleepStats", { date => $date } );

    return $result->{sleepStats};

}

sub getLatestSleepRecord {

    my $self = shift;
    my ($date) = @_;

    defined $date ? $self->_check_date_format($date) : $date =
      $self->_get_date();

    my $result =
      $self->_request_json( "getLatestSleepRecord", { date => $date } );

    return $result->{sleepRecord};

}

sub logout {

    my $self = shift;

    $self->_request_json("logout");

}

1;

__END__


=head1 NAME

WebService::Zeo - OO Perl API used to fetch sleep data from myzeo.com

=head1 SYNOPSIS

Sample Usage:

    use WebService::Zeo;
    
    my $zeo = WebService::Zeo->new(
        # Requires API registration
        'apikey' => 'XXYYZZ...',
        # Credentials used to login to myzeo
        'username' => 'user@domain.com',
        'password' => 'foo' 
    );
    
    # Alternatively a config file can be used - generated by initialize_zeo_config.pl
    
    my $zeo = WebService::Zeo->new(config => '/home/user/zeo.conf');
    
    print "Overall Average ZQ Score = " . $zeo->get_overall_average_zq_score() . "\n";
    
    print "Overall Average Day Feel Score = " . $zeo->get_overall_average_day_feel_score() . "\n";
    
    print "Overall Average Morning Feel Score = " . $zeo->get_overall_average_morning_feel_score() . "\n";
    
    print "Overall Average Sleep Stealer Score = " . $zeo->get_overall_average_sleep_stealer_score() . "\n";
    
    my @dates = $zeo->get_all_dates_with_sleep_data();
    print "Total recordered dates of sleep data = " , $#dates , "\n";
    
    my @dates_in_range = $zeo->get_dates_with_sleep_data_in_range("2010-12-01","2010-12-04");
    print "Total recordered dates of sleep data = " . $#dates_in_range . "\n";
    
    print Dumper $zeo->get_sleep_stats_for_date("2010-12-27");
    
    print Dumper $zeo->get_sleep_record_for_date("2010-12-27");
    
    print Dumper $zeo->get_previous_sleep_stats("2010-12-31");
    
    print Dumper $zeo->get_previous_sleep_record("2010-12-31");
    
    print Dumper $zeo->get_next_sleep_stats("2010-12-25");
    
    print Dumper $zeo->get_next_sleep_record("2010-12-25");
    
    print Dumper $zeo->get_earliest_sleep_stats();
    
    print Dumper $zeo->get_earliest_sleep_record();
    
    print Dumper $zeo->getLatestSleepStats();
    
    print Dumper $zeo->getLatestSleepRecord();

=head1 DESCRIPTION

Zeo (http://myzeo.com) is a product and program that measures your personal sleep patterns 
and records key information to help you learn to get a better nights sleep.
C<WebService::Zeo> provides an OO API for fetching this sleep data from myzeo.com.

The following information is required in order to use the API:
  - Username for your myzeo.com account (e.g. username@domain.com)
  - Password for your myzeo.com account
  - API Key (Can be obtained at http://mysleep.myzeo.com/api/api.shtml)

This module currently supports the JSON REST-based API and uses HTTPS.  Testing has been
performed against server version 1.0.4158 (as of 1/1/11).  

=head1 METHODS

See MyZeo developer API documentation for a detailed description of methods, parameters, requests, and responses.
This module implements all supported methods in the service catalog:

Overall Average Functions:

    * getOverallAverageZQScore - Returns the average ZQ score for the user.
    * getOverallAverageDayFeelScore - Returns the average score for how the user felt during the day.
    * getOverallAverageMorningFeelScore - Returns the average score for how the user felt in the morning.
    * getOverallAverageSleepStealerScore - Returns the average sleep stealer score for the user.


Date Functions:

    * getAllDatesWithSleepData - Returns an array of ZeoDate objects representing dates for which sleep data is available.
    * getDatesWithSleepDataInRange - Returns an array of ZeoDate objects for which sleep data is available inclusive in dates.
    * getSleepStatsForDate - Returns the SleepStats for the specified date.
    * getSleepRecordForDate - Returns the SleepRecord for the specified date.


Paging Functions:

    * getPreviousSleepStats - Returns the SleepStats (grouped by day) for the latest date prior to the specified date.
    * getPreviousSleepRecord - Returns the SleepRecord for the latest date prior to the specified date.
    * getNextSleepStats - Returns the SleepStats (grouped by day) for the earliest date after the specified date.
    * getNextSleepRecord - Returns the SleepStats for the earliest date after the specified date.
    * getEarliestSleepStats - Returns the SleepStats (grouped by day) with the earliest date on record for the current user.
    * getEarliestSleepRecord - Returns the SleepRecord with the earliest date on record for the current user.
    * getLatestSleepStats - Returns the SleepStats (grouped by day) with the latest date on record for the current user.
    * getLatestSleepRecord - Returns the SleepRecord with the latest date on record for the current user.


Miscellaneous Functions:

    * logout - Logs the user out of the API and closes the session.


=head1 EXAMPLE CODE

See dump_zeo_csv.pl

=head1 AUTHOR

Eric Blue <ericblue76@gmail.com> - http://eric-blue.com

=head1 COPYRIGHT

Copyright (c) 2011 Eric Blue. This program is free
software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=cut




