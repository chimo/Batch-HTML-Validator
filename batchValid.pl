#!/usr/bin/perl -T

use WebService::Validator::HTML::W3C;
use XML::XPath;

my $v = WebService::Validator::HTML::W3C->new(
        detailed    =>  1
        );

# Use our local validator; not validator.w3.org
$v->validator_uri("http://localhost/w3c-validator/check");

# Content type
print "Content-type: text/html\n\n";
print qq{<!DOCTYPE html>
<html lang="en">
<head>
    <title>Validator Results</title>
</head>
<body>
<div>
<h1>Validator Results</h1>
};

# Read POST data
read(STDIN, $data, $ENV{'CONTENT_LENGTH'});

# Convert in a sane format (split at "&", split at "=", urldecode, shove in associative array)
@fv_pairs = split /\&/ , $data;

foreach $pair (@fv_pairs) {
    if($pair=~m/([^=]+)=(.*)/) {
        $field = $1;
        $value = $2;
        $value =~ s/\+/ /g;
        $value =~ s/%([\dA-Fa-f]{2})/pack("C", hex($1))/eg;
        $INPUT{$field}=$value;
    }
}

# Separate urls by newline
@values = split(/\r\n/, $INPUT{'urls'});

# For each url, send to validator
foreach $val (@values) {

    if( $val eq '' ) {
        next; # Skip blank lines (TODO: remove blank lines as part of cleanup before this loop)
    }

    if ( $v->validate($val) ) {
        # Announce if valid
        if ( $v->is_valid ) {
            if ( !exists($INPUT{'hidevalid'}) ) {
                printf ("<div class='valid'><h2>%s is valid</h2>\n", $v->uri);
            }
        }
        else {
            printf ("<div class='invalid'>\n<h2>%s is not valid</h2>\n", $v->uri);
        }

        # List warnings
        if ( !exists($INPUT{'hidewarnings'}) ) {
            if($v->warningcount > 0) {
                print "<div class='errors'>\n<h3>Warnings</h3>\n<ul>\n";
                foreach my $warning ( @{$v->warnings} ) {
                    printf("<li class='warning'>%s at line %d\n", $warning->msg,
                            $warning->line);

                    if( (!exists($INPUT{'hidecontext'}) && (defined($warning->source))) ) {
                        printf("<p>%s</p>", $warning->source);
                    }

                    print("</li>");
                }
                print "</ul>\n</div>\n";
            }
        }

        # List errors
        if($v->errorcount > 0) {
            print "<div class='errors'>\n<h3>Errors</h3>\n<ul>\n";
            foreach my $error ( @{$v->errors} ) {
                printf("<li class='error'>%s at line %d\n", $error->msg,
                        $error->line);

                if( !exists($INPUT{'hideexpl'}) ) {
                    printf("<p>%s</p>", $error->explanation);
                }

                if( (!exists($INPUT{'hidecontext'}) && (defined($error->source))) ) {
                    printf("<p>%s</p>", $error->source);
                }

                print("</li>");
            }
            print "</ul>\n</div>\n";
        }

        print '</div>';
    }
    else { # Something went wrong; couldn't validate document :(
        printf ("<h2>Failed to validate %s: %s</h2>", $val, $v->validator_error);
    }

    # Sleep between requests if we're using the W3C's servers ( as per: http://validator.w3.org/docs/api.html#requestformat )
    if($v->uri() eq 'http://validator.w3.org/check') {
        sleep(1);
    }
}
print "\n</div>\n</body>\n</html>";