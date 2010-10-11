#!perl -T

use Test::More tests => 2;

my @list = qw/foo bar baz/;
my $expected = join q{ }, @list;

use PerlX::QuoteOperator qwuc => { -emulate => 'qw', -with => sub (@) { @_ } };

# multi-line
is_deeply [ qwuc{
    foo
    bar
    baz}], \@list, 'advanced qw multi-line test';

use PerlX::QuoteOperator qwS => {
    -emulate => 'qw',
    -with    => sub (@) { join q{ }, @_ },
};
is qwS/foo bar baz/, $expected, 'advanced qw parser test';


# TBD - test import() is working correctly.  Test nothing added to symbol table after a use P::QO ();
