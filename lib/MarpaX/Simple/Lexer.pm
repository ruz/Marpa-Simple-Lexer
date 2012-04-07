use 5.010;
use strict;
use warnings;

package MarpaX::Simple::Lexer;
our $VERSION = '0.01';

=head1 NAME

MarpaX::Simple::Lexer - simplify lexing for Marpa parser

=head1 SYNOPSIS

    use 5.010;
    use strict;
    use warnings;
    use lib 'lib/';

    use Marpa::XS;
    use MarpaX::Simple::Lexer;

    my $grammar = Marpa::XS::Grammar->new( {
        actions => 'main',
        default_action => 'do_what_I_mean',
        start   => 'query',
        rules   => [
            {
                lhs => 'query', rhs => [qw(condition)],
                min => 1, separator => 'OP', proper => 1, keep => 1,
            },
            [ condition => [qw(word)] ],
            [ condition => [qw(quoted)] ],
            [ condition => [qw(OPEN-PAREN SPACE? query SPACE? CLOSE-PAREN)] ],
            [ condition => [qw(NOT condition)] ],

            [ 'SPACE?' => [] ],
            [ 'SPACE?' => [qw(SPACE)] ],
        ],
        lhs_terminals => 0,
    });
    $grammar->precompute;
    my $recognizer = Marpa::XS::Recognizer->new( { grammar => $grammar } );

    use Regexp::Common qw /delimited/;

    my $lexer = MyLexer->new(
        recognizer => $recognizer,
        tokens => {
            word          => qr{\b\w+\b},
            'quoted'      => qr[$RE{delimited}{-delim=>qq{\'\"}}],
            OP            => qr{\s+(OR)\s+|\s+},
            NOT           => '!',
            'OPEN-PAREN'  => '(',
            'CLOSE-PAREN' => ')',
            'SPACE'       => qr{\s+()},
        },
        debug => 1,
    );

    $lexer->recognize(\*DATA);

    use Data::Dumper;
    print Dumper $recognizer->value;

    sub do_what_I_mean {
        shift;
        my @children = grep defined && length, @_;
        return scalar @children > 1 ? \@children : shift @children;
    }

    package MyLexer;
    use base 'MarpaX::Simple::Lexer';

    sub grow_buffer {
        my $self = shift;
        my $rv = $self->SUPER::grow_buffer( @_ );
        ${ $self->buffer } =~ s/[\r\n]+//g;
        return $rv;
    }

    package main;
    __DATA__
    hello !world OR "he hehe hee" ( foo OR !boo )

=head1 WARNING

This is experimental module in alpha stage I cooked during weekend to
simplify and speed up writing marpa grammar and lexer for vCards.

I'm publishing it to collect feedback and because I believe it can be very
useful to people experimenting with Marpa.

=head1 DESCRIPTION

This module helps you start with L<Marpa::XS> parser and simplifies lexing.

=head1 TUTORIAL

=head2 Where to start

Here is template you can start a new parser from:

    use strict; use warnings;

    use Marpa::XS;
    use MarpaX::Simple::Lexer;

    my $grammar = Marpa::XS::Grammar->new( {
        start   => 'query',
        rules   => [
            [ query => [qw(something)] ],
        ],
        lhs_terminals => 0,
    });
    $grammar->precompute;
    my $recognizer = Marpa::XS::Recognizer->new( { grammar => $grammar } );
    my $lexer = MarpaX::Simple::Lexer->new(
        recognizer => $recognizer,
        tokens => {},
        debug => 1,
    );

    $lexer->recognize(\*DATA);

    __DATA__
    hello !world "he hehe hee" ( foo OR boo )

It's a working program that prints the following output:

    Expect token(s): 'something'
    Buffer start: hello !world "he heh...
    Unknown token: 'something'
    Unexpected message, type "parse exhausted" at ...

First line says that at this moment parser expects 'something'.
It's going to look for it in the following text (second line).
Third line says that lexer doesn't know anything about 'something'.
It's not a surprise that parsing fails.

What can we do with 'something'? We either put it into grammar or
lexer. In above example it's pretty obvious that it's gonna be in
the grammar.

=head2 Put some grammar

    rules   => [
        # over query is a sequence of conditions separated with OPs
        {
            lhs => 'query', rhs => [qw(condition)],
            min => 1, separator => 'OP', proper => 1, keep => 1,
        },
        # each condition can be one of the following
        [ condition => [qw(word)] ],
        [ condition => [qw(quoted)] ],
        [ condition => [qw(OPEN-PAREN SPACE? query SPACE? CLOSE-PAREN)] ],
        [ condition => [qw(NOT condition)] ],
    ],

Our program works and gives us helpful results:

    Expect token(s): 'word', 'quoted', 'OPEN-PAREN', 'NOT'
    Buffer start: hello !world OR "he ...
    Unknown token: 'word'
    ...

=head2 First token

    tokens => {
        word => qr{\w+},
    },

Ouput:

    Expect token(s): 'word', 'quoted', 'OPEN-PAREN', 'NOT'
    Buffer start: hello !world OR "he ...
    Token 'word' matched hello
    Unknown token: 'quoted'
    Unknown token: 'OPEN-PAREN'
    Unknown token: 'NOT'
    Expect token(s): 'OP'

Congrats! First token matched. More tokens:

    use Regexp::Common qw /delimited/;

    my $lexer = MarpaX::Simple::Lexer->new(
        recognizer => $recognizer,
        tokens => {
            word => qr{\b\w+\b},
            OP => qr{\s+|\s+OR\s+},
            NOT => '!',
            'OPEN-PAREN' => '(',
            'CLOSE-PAREN' => ')',
            'quoted' => qr[$RE{delimited}{-delim=>qq{\'\"}}],
        },
        debug => 1,
    );

=head2 Tokens matching empty string

You can not have such. In our example grammar we have 'SPACE?' that
is optional. You could try to use C<qr{\s*}>, but lexer would die
with an error. Instead use the following:

    rules   => [
        ...
        [ 'SPACE?' => [] ],
        [ 'SPACE?' => [qw(SPACE)] ],
    ],
    ...
    tokens => {
        ...
        'SPACE'       => qr{\s+},
    },

=head2 Lexer's ambiguity

This module uses marpa's alternative input model what allows you to
describe ambiguous lexer, e.g. several tokens starts at the same point.
This is not always give you multiple results, but allows to start
faster and keep improving tokens and grammar to avoid unnecessary
ambiguity cases.

=head2 Longest token match

Let's look at string "x OR y". It should match "word OP word",
but it matches "word OP word OP word". This happens because of
how we defined OP token. If we change it to C<qr{\s+OR\s+|\s+}> then
results are better.

=head2 Input buffer

By default lexer reads data from the input stream in chunks into
a buffer and grow the buffer only when it's shorter than
C<min_buffer> bytes. By default it's 4kb. This is good for memory
consuption, but it can result in troubles when a terminal may be
larger than a buffer. For example consider a document with embedded
base64 encoded binary files. You can use several solutions to
workaround this problem.

Read everything into memory. Simplest way out. It's not default
value to avoid encouragement:

    my $lexer = MarpaX::Simple::Lexer->new(
        min_buffer => 0,
        ...
    );

Use larger buffer:

    my $lexer = MarpaX::Simple::Lexer->new(
        min_buffer => 10*1024*1024, # 10MB
        ...
    );

Use built in protection from such cases. When a regular expression
token matches whole buffer and buffer still can grow then lexer
grows buffer and retries. This allows you to write a regular
expression that matches till end of token or end of buffer (C<$>).
Note that this may result in token incomplete match if input ends
right in the middle of it.

    tokens => {
        ...
        'text-paragraph' => qr{\w[\w\s]+?(?:\n\n|$)},
    },

Adjust grammar. In most cases you can split long terminal into
multiple terminals with limitted length. For example:

    rules   => [
        ...
        { lhs => 'text', rhs => 'text-chunk', min => 1 },
    ],

=head2 Filtering input

Input can be filtered with subclassing grow_buffer method:

    package MyLexer;
    use base 'MarpaX::Simple::Lexer';

    sub grow_buffer {
        my $self = shift;
        my $rv = $self->SUPER::grow_buffer( @_ );
        ${ $self->buffer } =~ s/[\r\n]+//g;
        return $rv;
    }

=head2 Actions

The simplest possible action that can produce some results:

    my $grammar = Marpa::XS::Grammar->new( {
        actions => 'main',
        default_action => 'do_what_I_mean',
        ...
    );
    sub do_what_I_mean {
        shift;
        my @children = grep defined && length, @_;
        return @children > 1 ? \@children : shift @children;
    }
    ...

    $lexer->recognize(\*DATA);

    use Data::Dumper;
    print Dumper $recognizer->value;

=head2 Token's values

Values of tokens are set to whatever token matches in the input,
however for regexp tokens you can use $1 to set value. Here is
part of data from our example:

    '(',
    ' ',
    [ ...

Paren is followed by optional space. We can change SPACE token:

        'SPACE'       => qr{\s+()},

New token captures empty string into $1 and it skipped by default
action.

Similar trick can be used with OP, but to cature 'OR' without spaces:

        OP            => qr{\s+(OR)\s+|\s+},

=head2 What's next

Add more actions. Experiment. Enjoy.

=cut

sub new {
    my $proto = shift;
    my $self = bless { @_ }, ref $proto || $proto;
    return $self->init;
}

sub init {
    my $self = shift;

    my $tokens = $self->{'tokens'};
    while ( my ($token, $match) = each %$tokens ) {
        my $type = ref $match ? 'RE'
            : length $match == 1 ? 'CHAR'
            : 'STRING';
        $self->{ $type }{ $token } = $match;
    }

    $self->{'min_buffer'} //= 4*1024;
    $self->{'buffer'} //= '';

    return $self;
}

sub buffer { \$_[0]->{'buffer'} }

sub grow_buffer {
    my $self = shift;
    local $/ = \($self->{'min_buffer'}*2);
    $self->{'buffer'} .= readline($_[0]) // return 0;
    return 1 && $self->{'min_buffer'};
}

sub recognize {
    my $self = shift;
    my $fh = shift;

    my $rec = $self->{'recognizer'};
    my ($RE, $CHAR, $STRING) = @{$self}{qw(RE CHAR STRING)};

    my $buffer = $self->buffer;
    my $buffer_can_grow = $self->grow_buffer( $fh );

    while ( length $$buffer ) {
        my $expected = $rec->terminals_expected;
        die "failed to parse" unless @$expected;
        say STDERR "Expect token(s): ". join(', ', map "'$_'", @$expected)
            if $self->{'debug'};

        say STDERR "Buffer start: ". $self->dump_buffer .'...'
            if $self->{'debug'};

        my $first_char = substr $$buffer, 0, 1;
        my $at_least_on_match = 0;
        foreach my $token ( @$expected ) {
            REDO:

            my ($what, $matched, $match, $length);
            if ( defined( $what = $CHAR->{ $token } ) ) {
                ($matched, $match, $length) = (1, $first_char, 1)
                    if $what eq $first_char;
            }
            elsif ( defined( $what = $STRING->{ $token } ) ) {
                $length = length $what;
                ($matched, $match) = (1, $what)
                    if $what eq substr $$buffer, 0, $length;
            }
            elsif ( defined( $what = $RE->{ $token } ) ) {
                if ( $$buffer =~ /^($what)/ ) {
                    ($matched, $match, $length) = (1, $2//$1, length $1);
                    if ( $length == length $$buffer && $buffer_can_grow ) {
                        $buffer_can_grow = $self->grow_buffer( $fh );
                        goto REDO;
                    }
                }
            }
            else {
                say STDERR "Unknown token: '$token'" if $self->{'debug'};
                next;
            }

            unless ( $matched ) {
                say STDERR "No '$token' in ". $self->dump_buffer if $self->{'debug'};
                next;
            }

            unless ( $length ) {
                die "Token '$token' matched empty string. This is not supported.";
            }
            say STDERR "Token '$token' matched ". $self->dump_buffer( $length )
                if $self->{'debug'};

            $rec->alternative( $token, $match, $length );
            $at_least_on_match = 1;
        }
        say STDERR '' if $self->{'debug'};

        my $skip = 1;
        unless ( $rec->earleme_complete ) {
            if ( $rec->exhausted ) {
                # if didn't find match and parser is exhausted
                # then we lost
                die "exhausted" unless $at_least_on_match;

                # otherwise we won
                $rec->end_input;
                return $rec;
            }
            $skip++ while !$rec->earleme_complete;
            $skip++;
        }
        substr $$buffer, 0, $skip, '';
        $buffer_can_grow = $self->grow_buffer( $fh )
            if $buffer_can_grow && $self->{'min_buffer'} > length $$buffer;
    }
    $rec->end_input;
    return $rec;
}

sub dump_buffer {
    my $self = shift;
    my $show = shift // 20;
    my $str = $show? substr( $self->{'buffer'}, 0, $show ) : $self->{'buffer'};
    return $str =~ s/([^\x20-\x7E])/'\\x{'. hex( ord $1 ) .'}' /gre;
}

=head1 AUTHOR

Ruslan Zakirov E<lt>Ruslan.Zakirov@gmail.comE<gt>

=head1 LICENSE

Under the same terms as perl itself.

=cut

1;
