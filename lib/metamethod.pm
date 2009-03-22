package metamethod; # make my methods meta!
use strict;
use warnings;
use Variable::Magic qw/wizard cast/;

sub import {
  my ($self, $code) = @_;
  my $caller = caller;

  my $method_name;

  my $wiz = wizard
      copy_key => 1,
      data  => sub { \$method_name },
      fetch => sub {
        return if (substr $_[2], 0, 1) eq '(';
        ${ $_[1] } = $_[2];
        $_[2] = 'invoke_method';
        return;
      };

  no strict 'refs';

  *{"$caller\::invoke_method"} = sub {
    my $invocant = shift;
    $code->($invocant, $method_name, \@_);
  };

  cast %{"::$caller\::"}, $wiz;
}
1;
