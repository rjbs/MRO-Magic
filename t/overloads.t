use strict;
use warnings;
use Test::More 'no_plan';

use metamethod ();

TODO: {
  local $TODO = 'figure out how the crap overloading works';

  my @calls;
  {
    package OLP; # overloads pass through
    metamethod->import(
      metamethod => sub {
        my ($self, $method, $args) = @_;
        push @calls, $method;
        return $method;
      },
      overloads  => 'metamethod',
      passthru   => [ 'ISA' ],
    );
  }

  my $olp = bless {} => 'OLP';
  my $str = "$olp";
  is($str, '(""', "we stringified to the stringification method name");
}
