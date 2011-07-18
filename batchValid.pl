#!/usr/bin/perl -T

use WebService::Validator::HTML::W3C;
use XML::XPath;

# using modified "warning" sub since the original one chokes when <m:line> is present but empty in SOAP response
sub my_warn {
    my $content = shift;
    my $xp = XML::XPath->new( xml => $content );

    my @warnings;

    my @messages = $xp->findnodes( '/env:Envelope/env:Body/m:markupvalidationresponse/m:warnings/m:warninglist/m:warning' );

    foreach my $msg ( @messages ) {
        my ($line, $col, $node);

        if( ($line = $xp->findvalue('./m:line', $msg)) eq "") {
            $line = undef;
        }

        if( ($col = $xp->findvalue('./m:col', $msg)) eq "") {
            $col = undef;
        }

        my $warning = WebService::Validator::HTML::W3C::Warning->new({ 
                      line => $line,
                      col  => $col,
                      msg  => $xp->find( './m:message', $msg )->get_node(1)->getChildNode(1)->getValue,
                  });

        push @warnings, $warning;
    }

    return \@warnings;
}


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
            # using modified "warning" sub since the original one chokes when <m:line> is present but empty in SOAP response
            $warnings = my_warn($v->_content);
            if(scalar(@{$warnings}) > 0) {
                print "<div class='warnings'>\n<h3>Warnings</h3>\n<ul>\n";
                foreach my $warning ( @{$warnings} ) {
                    if(defined($warning->line)) {
                        printf("<li>%s at line %d</li>\n", $warning->msg,
                            $warning->line);
                    }
                    else {
                        printf("<li>%s</li>\n", $warning->msg);
                    }

                }
                print "</ul>\n</div>\n";
            }
        }

        # List errors
        if($v->errorcount > 0) {
            print "<div class='errors'>\n<h3>Errors</h3>\n<ul>\n";
            foreach my $error ( @{$v->errors} ) {
                printf("<li class='error'>%s at line %d</li>\n", $error->msg,
                        $error->line);
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
