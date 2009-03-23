package metamethod; # make my methods meta!
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
    $code = $caller->can($$code);
    Carp::confess("can't find metamethod via name ${ $arg->{metamethod} }")
      unless reftype $code eq 'CODE';
  }

  if (do { no strict 'refs'; defined *{"$caller\::$metamethod"}{CODE} }) {
    Carp::confess("can't install metamethod as $metamethod; already defined");
  }

  my $handle_overloads;
  if ($arg->{handle_overloads}) {
    if (reftype $arg->{handle_overloads} eq 'CODE') {
      $to_install{__overload_metamethod__} = $arg->{handle_overloads};
      $handle_overloads = '__overload_metamethod__';
    } elsif ($arg->{handle_overloads} eq 'metamethod') {
      $handle_overloads = $metamethod;
    } else {
      Carp::confess("unknown value for handles_overloads");
    }
  }

  my $method_name;

  my $wiz = wizard
    copy_key => 1,
    data     => sub { \$method_name },
    fetch    => $self->_gen_fetch_magic({
      metamethod => $metamethod,
      passthru   => $arg->{passthru},
      handle_overloads => $handle_overloads,
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
  my $passthru   = $arg->{passthru};
  my $handle_overloads = $arg->{handle_overloads};

  return sub {
    return if $_[2] ~~ $passthru;

    my $is_ol = (substr $_[2], 0, 1) eq '(';
    return if $is_ol and ! $handle_overloads;

    ${ $_[1] } = $_[2];
    $_[2] = $is_ol ? $handle_overloads : '__metamethod__';
    return;
  };
}

1;
