#!perl

use Test::More tests => 7;

my $quux = 42;
sub get_quux() { $quux }

use PerlX::QuoteOperator with_scalar_prefix => {
    -emulate => 'q',
    -with    => sub { is_deeply [ @_ ], [ 42, 'foo { bar } baz' ], 'prefix' },
    -template => '($quux, %s)'

};

with_scalar_prefix {foo { bar } baz};

use PerlX::QuoteOperator with_scalar_suffix => {
    -emulate => 'q',
    -with    => sub { is_deeply [ @_ ], [ 'foo { bar } baz', 42 ], 'suffix' },
    -template => '(%s, $quux)'
};

with_scalar_suffix {foo { bar } baz};

use PerlX::QuoteOperator with_scalar_circumfix => {
    -emulate => 'q',
    -with    => sub { is_deeply [ @_ ], [ 42, 'foo { bar } baz', 42 ], 'circumfix' },
    -template => '($quux, %s, $quux)'
};

with_scalar_circumfix {foo { bar } baz};

use PerlX::QuoteOperator with_callback => {
    -emulate => 'q',
    -with    => sub { is_deeply [ @_ ], [ 'foo { bar } baz', 42 ], 'callback' },
    -template => '(%s, get_quux())'

};

with_callback {foo { bar } baz};

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
