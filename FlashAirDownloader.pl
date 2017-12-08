#!/usr/bin/env perl

use strict;
use LWP::Simple;
use Getopt::Std;

sub read_directory {
    my $card_address = shift;
    my $sync_directory = shift;
    my $dir = shift;
    $dir ||= '/';
    
    my $response = get "$card_address/command.cgi?op=100&DIR=$dir";

    my @dir_list = split /^/, $response;
    shift @dir_list; # get rid of WLANSD_FILELIST

    foreach my $file (@dir_list) {
        chomp $file;
        my %attributes;
        @attributes{'directory', 'filename', 'size', 'attribute', 'date', 'time'} = split /,/, $file;
        $attributes{'fullname'} = join '/', @attributes{'directory', 'filename'};
        $attributes{'target'} = $sync_directory . $attributes{'fullname'};
        $attributes{'target'} =~ s/\//\\/g;        
        $attributes{'is_directory'} = $attributes{'attribute'} & 16;
        $attributes{'date_bin'} = sprintf("%016b", $attributes{'date'});
        $attributes{'time_bin'} = sprintf("%016b", $attributes{'time'});
        
        $attributes{'timestamp'} = sprintf("%04d-%02d-%02d %02d:%02d:%02d", 
                                           1980 + oct("0b".substr($attributes{'date_bin'},0,7)), 
                                           oct("0b".substr($attributes{'date_bin'},7,4)),
                                           oct("0b".substr($attributes{'date_bin'},11,5)), 
                                           oct("0b".substr($attributes{'time_bin'},0,5)), 
                                           oct("0b".substr($attributes{'time_bin'},5,6)),
                                           oct("0b".substr($attributes{'time_bin'},11,4))); 

        if( $attributes{'is_directory'} ) {
            print "Checking for changes in $attributes{'fullname'}\n";
            if( !(-d $attributes{'target'}) ) {
                print "Creating $attributes{'target'} directory\n";
                mkdir $attributes{'target'};
            }
            read_directory($card_address, $sync_directory, $attributes{'fullname'});
        } else {
            if( (-e $attributes{'target'}) ) {
                 my $mtime = (stat $attributes{'target'})[9] - 1;
                 my $target_timestamp = sprintf("%04d-%02d-%02d %02d:%02d:%02d", (gmtime($mtime))[5]+1900,
                                                                                 (gmtime($mtime))[3],
                                                                                 (gmtime($mtime))[4]+1,
                                                                                 (gmtime($mtime))[2],
                                                                                 (gmtime($mtime))[1],
                                                                                 (gmtime($mtime))[0]);
                if( $attributes{'timestamp'} gt $target_timestamp ) {
                    print "Downloading $attributes{'target'}\n";
                    getstore("$card_address$attributes{'fullname'}",$attributes{'target'});
                }
            } else {
                print "Downloading $attributes{'target'}\n";
                getstore("$card_address$attributes{'fullname'}",$attributes{'target'});
            }
        }
        
    }
    
}

sub HELP_MESSAGE {
    print<<END;

    FlashAirDownloader.pl 
    
    Syncs the remote card to the local directory.
    
    ARGUMENTS:
       -c  Card Address
       -d  Download Directory (defaults to current directory)

END
    exit;
}

my %opts = ( );
getopts('c:d:', \%opts) or HELP_MESSAGE();

HELP_MESSAGE() unless( $opts{c} );

my $card_address   = $opts{c};
my $sync_directory = $opts{d} || '.';

unless( $card_address =~ /^http:/ ) {
    $card_address = 'http://' . $opts{c};
}

read_directory($card_address, $sync_directory);
