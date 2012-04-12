#!/usr/bin/env perl

use Test::More tests => 10;
use MarpaX::Simple::Lexer::Test;
my $test = 'MarpaX::Simple::Lexer::Test';

# simple success cases matching whole input
for my $case (
    { tokens => { word => qr/X/ }, input => "X" },
    { tokens => { word => qr/XX/ }, input => "XX" },
) {
    my ($lexer, $rec) = $test->recognize( %$case );
    is_deeply( $rec->value, \$case->{'input'} );
    is ${$lexer->buffer}, '';
}

# success case matching prefix
{
    my ($lexer, $rec) = $test->recognize(
        tokens => { word => qr/X/ }, input => "XY",
    );
    is_deeply( $rec->value, \"X" );
    is ${$lexer->buffer}, 'Y';
}

# simple failure case at the beginning
{
    my ($lexer, $rec) = $test->recognize(
        tokens => { word => qr/X/ },
        input => "Y",
    );
    is $rec->value, undef, 'failed to match';
    is ${$lexer->buffer}, 'Y';
}

# sequence that can not continue
# XXX: match fails and it's sad
{
    my ($lexer, $rec) = $test->recognize(
        rules => [
            { lhs => 'text', rhs => ['word'], min => 1 }
        ],
        tokens => { word => qr/X/ },
        input => "XXY",
    );
    is $rec->value, undef;
    is ${$lexer->buffer}, 'Y';
}
