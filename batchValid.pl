#!/usr/bin/perl -T

use WebService::Validator::HTML::W3C;

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
@values = split(/\n/, $INPUT{'urls'});

# For each url, send to validator
foreach $val (@values) {
    if ( $v->validate($val) ) {
        if ( $v->is_valid ) {
            if ( !exists($INPUT{'hidevalid'}) ) {
                printf ("<h2 class='valid'>%s is valid</h2>\n", $v->uri);
            }
        }
        else {
            printf ("<div class='invalid'>\n<h2 class='invalid'>%s is not valid</h2>\n<ul>\n", $v->uri);
            
            # List warnings (apparently the dev version of the validator is needed(?)) # TODO: Look into this
#            if ( !exists($INPUT{'hidewarnings'}) ) {
#                foreach my $warning ( @{$v->warnings} ) {
#                    printf("<li class='warning'>%s at line %d</li>\n", $warning->msg,
#                            $warning->line);
#                }
#            }

            # List errors
            foreach my $error ( @{$v->errors} ) {
                printf("<li class='error'>%s at line %d</li>\n", $error->msg,
                        $error->line);
            }
            print "</ul>\n</div>";
        }
    }
    else { # Something went wrong; couldn't validate document :(
        printf ("<h2>Failed to validate the website: %s</h2>", $v->validator_error);
    }

    # Sleep between requests if we're using the W3C's servers ( as per: http://validator.w3.org/docs/api.html#requestformat )
    if($v->uri() eq 'http://validator.w3.org/check') {
        sleep(1);
    }
}
print "\n</div>\n</body>\n</html>";

