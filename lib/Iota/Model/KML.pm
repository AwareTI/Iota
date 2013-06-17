package Iota::Model::KML;
use Moose;
use utf8;
use JSON qw/encode_json/;
use XML::Simple qw(:strict);

use Iota::Model::KML::LineString;

sub process {
    my ( $self, %param ) = @_;

    my $upload = $param{upload};
    my $schema = $param{schema};

    my $kml    = XMLin($upload->tempname,
        ForceArray => 1,
        KeyAttr    => {},
    );

    my $parsed;

    for my $mod (qw/LineString/){
        my $class = "Iota::Model::KML::$mod";
        my $test = $class->new->parse( $kml );
        next unless defined $test;

        $parsed = $test;
    }

    if (defined $parsed){

        return $parsed;

    }else{

        die("Unssuported KML\n");
    }

}

1;
