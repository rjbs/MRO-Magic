package metamethod;
use 5.010; # uvar magic does not work prior to version 10
use strict;
use warnings;

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

  my $overloads;
  if ($arg->{overloads}) {
    # XXX: detect name conflicts here -- rjbs, 2009-03-22
    if ($arg->{overloads} eq 'metamethod') {
      $overloads = $metamethod;
    } elsif (! ref $arg->{overloads}) {
      Carp::confess("unknown value for overloads");
    } elsif (reftype $arg->{overloads} eq 'CODE') {
      $to_install{__overload_metamethod__} = $arg->{overloads};
      $overloads = '__overload_metamethod__';
    } elsif (reftype $arg->{overloads} eq 'SCALAR') {
      $overloads = ${ $arg->{overloads} };
    } else {
      Carp::confess("unknown value for overloads");
    }
  }

  my $method_name;

  my $wiz = wizard
    copy_key => 1,
    data     => sub { \$method_name },
    fetch    => $self->_gen_fetch_magic({
      metamethod => $metamethod,
      overloads  => $overloads,
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

  cast %{"::$caller\::"}, $wiz;
}

sub _gen_fetch_magic {
  my ($self, $arg) = @_;

  my $metamethod = $arg->{metamethod};
  my $overloads  = $arg->{overloads};
  my $passthru   = $arg->{passthru};

  return sub {
    return if $_[2] ~~ $passthru;

    my $is_ol = (substr $_[2], 0, 1) eq '(';
    return if $is_ol and ! $overloads;

    ${ $_[1] } = $_[2];
    $_[2] = $is_ol ? $overloads : $metamethod;
    return;
  };
}

1;
