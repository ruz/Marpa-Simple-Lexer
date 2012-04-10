use Test::More;
use Test::Exception;

use Marpa::XS;
use MarpaX::Simple::Lexer;
use IO::String;
use Data::Dumper;

sub X {
    return 1;
}

my $grammar = Marpa::XS::Grammar->new( {
    actions => 'main',
    start => 'Parser',
    rules => [
        [ 'Parser'  => [ 'X' ], 'X' ],
    ],
    terminals => [qw/X/],
});

$grammar->precompute;

my @test_cases = (
    [ {X => qr/X/}, "X" ],
    [ {X => qr/XX/}, "XX" ],
);

for my $case (@test_cases) {
    my $recognizer = Marpa::XS::Recognizer->new( { grammar => $grammar } );
    my $lexer = MarpaX::Simple::Lexer->new(
        recognizer => $recognizer,
        tokens     => $case->[0],
    );

    my $io = IO::String->new($case->[1]);
    lives_ok {
        $lexer->recognize($io);
    };
    is(${ $recognizer->value }, 1);
}

done_testing();

