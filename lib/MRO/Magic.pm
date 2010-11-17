package MRO::Magic;
use 5.010; # uvar magic does not work prior to version 10
use strict;
use warnings;
# ABSTRACT: write your own method dispatcher

use Object::Anon ();
use Scalar::Util qw(reftype);
use Variable::Magic qw/wizard cast/;

=head1 WARNING

First off, at present (2009-05-25) this code requires a development version of
perl.  It should run on perl5 v10.1, but that isn't out yet, so be patient or
install a development perl.

Secondly, the API is not guaranteed to change in massive ways.  This code is
the result of playing around, not of careful design.

Finally, using MRO::Magic anywhere will impact the performance of I<all> of
your program.  Every time a method is called via MRO::Magic, the entire method
resolution class for all classes is cleared.

B<You have been warned!>

=head1 USAGE

First you write a method dispatcher.

  package MRO::Classless;
  use MRO::Magic
    metamethod => \'invoke_method',
    passthru   => [ qw(VERSION import unimport DESTROY) ];

  sub invoke_method {
    my ($invocant, $method_name, $args) = @_;

    ...

    return $rv;
  }

In a class using this dispatcher, any method not in the passthru specification
is redirected to C<invoke_method>, which can do any kind of ridiculous thing it
wants.  The C<$rv> in the C<invoke_method> above is the return value of the
method called.  In other words, invoke_method takes the place of the method
being called, down to returning the right value.  In the future, it I<may> be
possible to declare that your invoke_method returns coderefs to call, but at
present that is not the case.

Now you use the dispatcher:

  package MyDOM;
  use MRO::Classless;
  use mro 'MRO::Classless';
  1;

...and...

  use MyDOM;

  my $dom = MyDOM->new(type => 'root');

The C<new> call will actually result in a call to C<invoke_method> in the form:

  invoke_method('MyDOM', 'new', [ type => 'root' ]);

Assuming it returns an object blessed into MyDOM, then:

  $dom->children;

...will redispatch to:

  invoke_method($dom, 'children', []);

For examples of more practical use, look at the test suite.

=cut

sub new_stash {
  my ($self, $arg) = @_;

  my $stash = Object::Anon::Stash->new;

  if (@_ == 1 and reftype $_[0] eq 'CODE') {
    $arg = { metamethod => $_[0] };
  }

  my $method_name;

  my $wiz = wizard(
    copy_key => 1,
    data     => sub { \$method_name },
    fetch    => $self->_gen_fetch_magic({
      passthru   => $arg->{passthru},
    }),
  );

  my $code = $arg->{metamethod};

  $stash->add_method(dispatch_method => sub {
    my $invocant = shift;
    $code->($invocant, $method_name, \@_);
  });

  # if ($arg->{overload}) {
  #   my %copy = %{ $arg->{overload} };
  #   for my $ol (keys %copy) {
  #     next if $ol eq 'fallback';
  #     next if ref $copy{ $ol };
  #     
  #     my $name = $copy{ $ol };
  #     $copy{ $ol } = sub {
  #       $_[0]->$name(@_[ 1 .. $#_ ]);
  #     };
  #   }

  #   # We need string eval to set the caller to a variable. -- rjbs, 2009-03-26
  #   # We must do this before casting magic so that overload.pm can find the
  #   # right entries in the stash to muck with. -- rjbs, 2009-03-26
  #   die unless eval qq{
  #     package $caller;
  #     use overload %copy;
  #     1;
  #   };
  # }

  cast %$stash, $wiz;

  return $stash;
}

sub _gen_fetch_magic {
  my ($self, $arg) = @_;

  my $passthru   = $arg->{passthru};

  use Data::Dumper;
  return sub {
    return if $_[2] ~~ $passthru;

    return if substr($_[2], 0, 1) eq '(';

    ${ $_[1] } = $_[2];
    $_[2] = 'dispatch_method';

    return;
  };
}

1;
