#!perl

use Test::More tests => 6;

sub _quc1($)  { uc $_[0] }
sub _qquc1($) { uc $_[0] }

use PerlX::QuoteOperator quc1 => { -emulate => 'q', -with => \&_quc1 };
ok q{foobar} =~ /^foo/ && q{foobar} =~ /bar$/, 'verify precedence of q';
ok quc1{foobar} =~ /^FOO/ && quc1{foobar} =~ /BAR$/, 'custom named q has same precedence';

use PerlX::QuoteOperator qquc1 => { -emulate => 'qq', -with => \&_qquc1 };
ok qq{foobar} =~ /^foo/ && qq{foobar} =~ /bar$/, 'verify precedence of qq';
ok qquc1{foobar} =~ /^FOO/ && qquc1{foobar} =~ /BAR$/, 'custom named qq has same precedence';

use PerlX::QuoteOperator quc2 => { -emulate => 'q', -with => sub ($) { uc $_[0] } };
ok quc2{foobar} =~ /^FOO/ && quc2{foobar} =~ /BAR$/, 'custom anon q has same precedence';

use PerlX::QuoteOperator qquc2 => { -emulate => 'qq', -with => sub ($) { uc $_[0] } };
ok qquc2{foobar} =~ /^FOO/ && qquc2{foobar} =~ /BAR$/, 'custom anon qq has same precedence';
