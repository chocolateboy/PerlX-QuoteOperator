use strict;
use warnings;
use 5.010;

use Test::More tests => 2;

use PerlX::QuoteOperator qwuc => { 
    -emulate    => 'qw', 
    -with       => sub (@) { map { uc } @_ },
};

is_deeply [ qwuc{foo bar baz}, qw{one two three} ], [ qw{FOO BAR BAZ one two three} ];

# let's do list to hash
use PerlX::QuoteOperator qwHash => {
    -emulate    => 'qw',
    -with       => sub (@) { map { $_[$_] => $_ + 1 } 0 .. $#_ },
};

my %months = qwHash<Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec>;

is $months{ Jun }, 6;
