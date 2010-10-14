#!perl

use Test::More tests => 9;

use vars qw($QUUX);

BEGIN { $QUUX = 42 }

sub get_quux() { $QUUX }
sub multiline($) { "(qq|$/$/$/$/($_[0])$/$/$/$/|)" }

use PerlX::QuoteOperator with_scalar_prefix => {
    -emulate => 'q',
    -with    => sub { is_deeply [ @_ ], [ 42, 'foo { bar } baz' ], 'prefix' },
    -template => '($QUUX, %s)'

};

with_scalar_prefix {foo { bar } baz};

use PerlX::QuoteOperator with_scalar_suffix => {
    -emulate => 'q',
    -with    => sub { is_deeply [ @_ ], [ 'foo { bar } baz', 42 ], 'suffix' },
    -template => '(%s, $QUUX)'
};

with_scalar_suffix {foo { bar } baz};

use PerlX::QuoteOperator with_scalar_circumfix => {
    -emulate => 'q',
    -with    => sub { is_deeply [ @_ ], [ 42, 'foo { bar } baz', 42 ], 'circumfix' },
    -template => '($QUUX, %s, $QUUX)'
};

with_scalar_circumfix {foo { bar } baz};

use PerlX::QuoteOperator with_named_callback => {
    -emulate => 'q',
    -with    => sub { is_deeply [ @_ ], [ 'foo { bar } baz', 42 ], 'named callback' },
    -template => '(%s, get_quux())'

};

with_named_callback {foo { bar } baz};

use PerlX::QuoteOperator with_dereference => {
    -emulate  => 'q',
    -with     => sub { bless [ @_ ] },
    -template => '(%s)->get_quux()' # with_dereference(q{foo { bar } baz })->get_quux();
};

is(with_dereference {foo { bar } baz}, 42, 'dereference');
# make sure there are no side effects that prevent subsequent calls
is(with_dereference {foo { bar } baz}, 42, 'idempotence');

use PerlX::QuoteOperator with_duplicate => {
    -emulate  => 'q',
    -with     => sub { is_deeply [ @_ ], [ 'foo { bar } baz', 'foo { bar } baz' ], 'duplicate' },
    -template => '(%s, %1$s)'
};

with_duplicate {foo { bar } baz};

use PerlX::QuoteOperator with_callback => {
    -emulate  => 'q',
    -with     => sub { is_deeply [ @_ ], [ 'foo { bar } baz', 42, 'foo { bar } baz' ], 'callback' },
    -template => sub { sprintf('(%s, %d, %1$s)', shift, $QUUX) }
};

with_callback {foo { bar } baz};

use PerlX::QuoteOperator with_multiline_callback => {
    -emulate  => 'q',
    -with     => sub { is_deeply [ @_ ], [ "$/$/$/$/(q{foo { bar } baz})$/$/$/$/" ], 'multiline callback' },
    -template => \&multiline
};

with_multiline_callback {foo { bar } baz};
