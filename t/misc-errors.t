use strict;
use warnings;
use Test::More 'no_plan';

use metamethod ();

{
  my $ok = eval {
    package Foo;
    sub __metamethod__ { "just here to cause problems" }
    metamethod->import( sub { 1 } );
    1;
  };

  my $error = $@;
  ok( ! $ok, "we can't use metamethod without custom name if conflict exists");
  like($error, qr/already/, "... got the right error, more or less");
}

{
  my $ok = eval {
    package Bar;
    metamethod->import(metamethod => \'doesnt_exist');
    1;
  };

  my $error = $@;
  ok( ! $ok, "we can't provide metamethod by name if it doesn't exist");
  like($error, qr/can't find/, "... got the right error, more or less");
}

