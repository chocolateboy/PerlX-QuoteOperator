package PerlX::QuoteOperator;
use strict;
use warnings;
use 5.008001;
use base 'Devel::Declare::Context::Simple';
use vars qw(@CARP_NOT);

use Carp qw(croak);
use Devel::Declare ();
use Scalar::Util qw(blessed);

our $VERSION = '0.02';

BEGIN { @CARP_NOT = (__PACKAGE__, __PACKAGE__ . '::URL', 'Devel::Declare') }

# we subclass Devel::Declare::Context::Simple and store our settings
# in fields in its hash, so make sure they're namespaced
our $qtype    = __PACKAGE__ . '::qtype';
our $template = __PACKAGE__ . '::template';
our $debug    = __PACKAGE__ . '::debug';

# return true if $ref ISA $class - works with non-references, unblessed references and objects
sub _isa($$) {
    my ($ref, $class) = @_;
    return blessed($ref) ? $ref->isa($class) : ref($ref) eq $class;
}

sub import {
    # XXX keep the trailing caller API for backwards compat with e.g. Junction::Quotelike
    # use Devel::Deprecate?
    my ($class, $name, $param, $caller) = @_;

    # not importing unless name & parameters provided (TBD... test these)
    return unless $name && $param;

    my $sub = $param->{ -with };

    croak('no -with param supplied') unless (defined $sub);
    croak('-with param is not a CODE ref') unless (_isa($sub, 'CODE'));

    my $self = ref($class) ? $class : $class->new;

    $caller ||= $param->{ -in } || caller;

    # quote-like operator to emulate.  Default is qq// unless -emulate is provided
    $self->{ $qtype } = $param->{ -emulate } || 'qq';

    # quote-like operator to emulate.  Default is qq// unless -emulate is provided
    $self->{ $qtype } = $param->{ -emulate } || 'qq';

    # debug or not to debug... that is the question
    $self->{ $debug } = $param->{ -debug } || 0;

    # an optional sub/string template allowing full control over the rewrite.
    # the sub/sprintf are called with the format and the quote as arguments,
    # and the result replaces the quote (including the -qtype prefix, delimiters and
    # any embedded escapes) e.g.
    #
    #     use PerlX::QuoteOperator 'sql', {
    #         -with     => \&_sql,
    #         -qtype    => 'q',
    #         -template => '(%s, get_dbh())'
    #     };
    #
    # sql { SELECT * FROM foo } -> sql(q{SELECT * FROM foo}, get_dbh())
    #
    # if no template is supplied, the same mechanism is used with a default template of
    # (%s)

    my $format = $param->{ -template } || '(%s)';
    my $formatter;

    if (_isa($format, 'CODE')) {
        $formatter = $format;
    } else {
        my $ref = ref $format;

        if ($ref) {
            croak("invalid template type ($ref): -template value must be a string or CODE ref");
        } else {
            $formatter = sub ($) { sprintf($format, $_[0]) };
        }
    }

    $self->{ $template } = $formatter;

    $self->{ $debug } = $param->{ -debug } || 0;

    # Create D::D trigger for $name in calling program
    Devel::Declare->setup_for(
        $caller, {
            $name => { const => sub { $self->parser(@_) } },
        },
    );

    no strict 'refs';
    *{$caller.'::'.$name} = $sub;
}

# extract the quote, then re-insert it wrapped in parentheses e.g.
#
#     qURL|http://www.example.com| => qURL(q|http://www.example.com|)
#
# this ensures custom quotes have the same precedence as builtins
# (see t/precedence.t)

sub parser {
    my $self = shift;
    $self->init(@_);
    $self->skip_declarator;          # skip past "http"
    $self->skipspace;

    my $line = $self->get_linestr;   # get me current line of code

    # $offset points to the position after the custom quote token and any
    # trailing spaces e.g.
    #
    #     qURL (http://www.example.com) . "foobar"
    #          ^
    #          |

    my $offset = $self->offset;

    # toke_scan_str() uses perl's builtin quote parser to extract a delimited
    # string without inserting it into the parse tree; the two options
    # ensure the quote 1) includes the outer delimiters /quotation marks
    # and 2) preserves any backslashes used to escape embedded delimiters i.e.
    # the quote is returned verbatim

    my $length = Devel::Declare::toke_scan_str($offset, keep_delimiters => 1, keep_escapes => 1);

    # trap accidental uses of myQuote q{...}
    if ($length < 0) { # XXX B::Compiling could be used here to show the file/line
        substr($line, $offset, 0) = '(HERE -->)';
        croak "malformed quote: $line";
    }

    # now 1) grab the quote from the temp variable perl stores it in internally,
    # and 2) clear the temp variable so perl doesn't think it has a pending token

    my $quote = Devel::Declare::get_lex_stuff;

    Devel::Declare::clear_lex_stuff;

    # The quote scanner above may have consumed multiple lines, so we need to update our
    # line string to reflect any changes. The offset still points to the
    # beginning of the quote

    $line = $self->get_linestr;

    # now we have the quoted string: remove all $length of its characters from the input buffer
    # and replace them with the parenthesized, perl-quoted version.

    my $replacement = $self->{ $template }->($self->{ $qtype } . $quote);

    croak 'replacement string is undefined' unless (defined $replacement);
    warn "replacement: $replacement$/" if ($self-> { $debug });
    substr($line, $offset, $length) = $replacement;

    # et voila!
    #
    #     qURL (qq(http://www.example.com)) . "foobar"
    #          ^
    #          |
    #
    # perl is none the wiser, and continues on its merry way

    # pass back to perl
    $self->set_linestr( $line );
    warn "line: $line$/" if $self->{ $debug };

    return; # i.e. return undef
}


1;


__END__

=head1 NAME

PerlX::QuoteOperator - Create new quote-like operators in Perl

=head1 VERSION

Version 0.02


=head1 SYNOPSIS

Create a quote-like operator which converts text to uppercase:

    use PerlX::QuoteOperator quc => {
        -emulate => 'q', 
        -with    => sub ($) { uc $_[0] }, 
    };

    say quc/do i have to $hout/;

    # => DO I HAVE TO $HOUT


=head1 DESCRIPTION

=head2 QUOTE-LIKE OPERATORS

Perl comes with some very handy Quote-Like Operators 
L<http://perldoc.perl.org/perlop.html#Quote-Like-Operators> :)

But what it doesn't come with is some easy method to create your own quote-like operators :(

This is where C<PerlX::QuoteOperator> comes in.  Using the fiendish L<Devel::Declare> under its hood,
it "tricks" - sorry "helps!" - the perl parser to provide new first class quote-like operators.

=head2 HOW DOES IT DO IT?

The subterfuge doesn't go that deep.  If we take a look at the SYNOPSIS example:

    say quc/do i have to $hout/;

Then all C<PerlX::QuoteOperator> actually does is convert this to the following before perl compiles it:

    say quc(q/do i have to $hout/);

C<PerlX::QuoteOperator> installs the sub supplied via the C<-with> option in the calling
package (i.e. the package from which C<use PerlX::QuoteOperator ...> is called) under the
name supplied in the first argument of the use statement.

    use PerlX::QuoteOperator quc => {
        -emulate => 'q',
        -with    => sub($) { ... }, # installed as &{caller}::quc
    };

The number of arguments supplied to subs implementing custom quote operators is
dependent on the number of arguments returned by the builtin they emulate and wrap (and the
context in which the builtin is called); so, by default, a sub emulating C<q> or C<qq> will receive
a single string, and a sub emulating C<qw> will receive a (possibly empty) list &c.

=head2 WHY?

Bit like climbing Mount Everest... because we can!  ;-)

Is really having something like:

    say quc/do i have to $hout/;

so much better than:

    say uc 'do i have to $hout';

or, more apt, this:

    say uc('do i have to $hout');

Probably not... at least in the example shown.  But things like this are certainly eye-catching:

    use PerlX::QuoteOperator::URL 'qh';

    my $content = qh( http://transfixedbutnotdead.com );   # does HTTP request

And this:

    use PerlX::QuoteOperator qwHash => { 
        -emulate    => 'qw',
        -with       => sub (@) { my $n; map { $_ => ++$n } @_ },
    };

    my %months = qwHash/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/;

Or even this:

    use Quote::SQL dbh => DBI->connect(...);

    my $rows = sql { SELECT * FROM foo WHERE bar = ? }->selectall_hashrefs(42);

=head1 EXPORT

By default, nothing is exported:

    use PerlX::QuoteOperator;    # => imports nothing

A quote operator is imported when the package is passed a name and a C<-with> option e.g.

    use PerlX::QuoteOperator my_quote_operator => { -with => ... }

A hashref is used to pass the options.

=head2 PARAMETERS

=head3 -emulate

Specifies the builtin quote operator that should be emulated. C<q>, C<qq> & C<qw> have all been tested.

Default: emulates C<qq>.

=head3 -with

Supply an anonymous sub or code ref and it will be installed under the specified name.

This is a mandatory parameter.

=head3 -in

The name of the package the quote operator should be installed into: defaults to the caller.

=head3 -template

This takes either a string or a callback function.

=over

=item * string

A C<sprintf>-style format string used to wrap/rewrite the quote. This can be used
to pass around state and other tricks. The replacement expression is given by:

    sprintf($format, $quoted)

where C<$format> is the parameter to the C<-template> option, and C<$quoted> is the quote with the
C<-qtype> token prefixed (C<qq> by default). If no template is supplied, it defaults to C<(%s)>.

=item * callback

A code ref or anonymous sub that is passed the quoted string (again, with the C<-qtype> token prefixed)
and which returns the formatted replacment string.

=back

Note that the replacement string should usually be parenthesized to ensure that custom quote-like operators
have the same precedence as the builtins.

=head3 -debug

If set, then the transmogrified line is printed (using C<warn>) so that you can see what C<PerlX::QuoteOperator> has done!

    -debug => 1

Default:  No debug.

=head1 METHODS

=head2 import

Usually called via C<use> to install the perl parser hook in the calling package that enables the specified custom
quote-like sub.

=head1 SEE ALSO

=over 4

=item * L<Filter::QuasiQuote>

=item * L<Junction::Quotelike>

=item * L<PerlX::QuoteOperator::URL>

=item * L<Sub::Quotelike>

=back



=head1 AUTHOR

Barry Walsh, C<< <draegtun at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-perlx-quoteoperator at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=PerlX-QuoteOperator>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc PerlX::QuoteOperator


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=PerlX-QuoteOperator>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/PerlX-QuoteOperator>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/PerlX-QuoteOperator>

=item * Search CPAN

L<http://search.cpan.org/dist/PerlX-QuoteOperator/>

=back


=head1 ACKNOWLEDGEMENTS

From here to oblivion!:  L<http://transfixedbutnotdead.com/2009/12/16/url-develdeclare-and-no-strings-attached/>

And a round of drinks for the mad genius of L<MST|http://search.cpan.org/~mstrout/> for creating L<Devel::Declare> in the first place!


=head1 DISCLAIMER

This is (near) beta software.   I'll strive to make it better each and every day!

However I accept no liability I<whatsoever> should this software do what you expected ;-)

=head1 COPYRIGHT & LICENSE

Copyright 2009-2010 Barry Walsh (Draegtun Systems Ltd | L<http://www.draegtun.com>), all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

