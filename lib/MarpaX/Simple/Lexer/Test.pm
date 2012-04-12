use 5.010; use strict; use warnings;

package MarpaX::Simple::Lexer::Test;

use Marpa::XS;
use MarpaX::Simple::Lexer;

sub simple_lexer {
    my $self = shift;
    my %args = (@_);
    my $grammar = Marpa::XS::Grammar->new({
        actions => 'MarpaX::Simple::Lexer::Test::Actions',
        start => 'text',
        default_action => 'do_what_I_mean',
        rules => [
            [ 'text'  => [ 'word' ] ],
        ],
        lhs_terminals => 0,
        (
            map { $_ => $args{$_} } grep exists $args{$_},
            qw(start rules lhs_terminals default_action),
        ),
    });
    $grammar->precompute;
    my $recognizer = Marpa::XS::Recognizer->new( { grammar => $grammar } );
    my $lexer = MarpaX::Simple::Lexer->new(
        tokens     => { word => 'test' },
        %args,
        recognizer => $recognizer,
    );

    return ($lexer, $recognizer, $grammar);
}

sub recognize {
    my $self = shift;
    my %args = (@_);

    my $input = delete $args{'input'};
    my $io;
    unless ( ref $input ) {
        open $io, '<', \$input;
    } else {
        $io = $input;
    }

    my @res = $self->simple_lexer( %args );
    $res[0]->recognize( $io );
    return @res;
}

package MarpaX::Simple::Lexer::Test::Actions;

sub do_what_I_mean {
    shift;
    my @children = grep defined && length, @_;
    return scalar @children > 1 ? \@children : shift @children;
}

1;
