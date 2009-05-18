package MRO::Magic;
use 5.010; # uvar magic does not work prior to version 10
use strict;
use warnings;

use mro;
use MRO::Define;
use Scalar::Util qw(reftype);
use Variable::Magic qw/wizard cast/;

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
