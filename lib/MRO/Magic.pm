package MRO::Magic;
use 5.010; # uvar magic does not work prior to version 10
use strict;
use warnings;
# ABSTRACT: write your own method dispatcher

use mro;
use MRO::Define;
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
wants.

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

sub import {
  my $self = shift;
  my $arg;

  if (@_ == 1 and reftype $_[0] eq 'CODE') {
    $arg = { metamethod => $_[0] };
  } else {
    $arg = { @_ };
  }

  my $caller     = caller;
  my %to_install;

  my $code       = $arg->{metamethod};
  my $metamethod = $arg->{metamethod_name} || '__metamethod__';

  if (reftype $code eq 'SCALAR') {
    Carp::confess("can't find metamethod via name ${ $arg->{metamethod} }")
      unless $code = $caller->can($$code);
  }

  if (do { no strict 'refs'; defined *{"$caller\::$metamethod"}{CODE} }) {
    Carp::confess("can't install metamethod as $metamethod; already defined");
  }

  my $method_name;

  my $wiz = wizard
    copy_key => 1,
    data     => sub { \$method_name },
    fetch    => $self->_gen_fetch_magic({
      metamethod => $metamethod,
      passthru   => $arg->{passthru},
    });

  $to_install{ $metamethod } = sub {
    my $invocant = shift;
    $code->($invocant, $method_name, \@_);
  };

  no strict 'refs';
  for my $key (keys %to_install) {
    *{"$caller\::$key"} = $to_install{ $key };
  }

  if ($arg->{overload}) {
    my %copy = %{ $arg->{overload} };
    for my $ol (keys %copy) {
      next if $ol eq 'fallback';
      next if ref $copy{ $ol };
      
      my $name = $copy{ $ol };
      $copy{ $ol } = sub {
        $_[0]->$name(@_[ 1 .. $#_ ]);
      };
    }

    # We need string eval to set the caller to a variable. -- rjbs, 2009-03-26
    # We must do this before casting magic so that overload.pm can find the
    # right entries in the stash to muck with. -- rjbs, 2009-03-26
    die unless eval qq{
      package $caller;
      use overload %copy;
      1;
    };
  }

  MRO::Define::register_mro($caller, sub {
    return [ undef, $caller ];
  });

  cast %{"::$caller\::"}, $wiz;
}

sub _gen_fetch_magic {
  my ($self, $arg) = @_;

  my $metamethod = $arg->{metamethod};
  my $passthru   = $arg->{passthru};

  use Data::Dumper;
  return sub {
    return if $_[2] ~~ $passthru;

    return if substr($_[2], 0, 1) eq '(';

    ${ $_[1] } = $_[2];
    $_[2] = $metamethod;
    mro::method_changed_in('UNIVERSAL');

    return;
  };
}

1;
