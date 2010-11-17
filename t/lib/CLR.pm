use strict;
use warnings;
package CLR; # class-less root
# Our test example will be a very, very simple classless/prototype calling
# system. -- rjbs, 2008-05-16

use MRO::Magic;

my $stash = MRO::Magic->new_stash({
  passthru   => [ qw(import export DESTROY AUTOLOAD) ],
  metamethod => sub {
    my ($invocant, $method, $args) = @_;

    Carp::cluck("@_");

    my $curr = $invocant;
    while ($curr) {
      return $curr->{$method}->($invocant, @$args) if exists $curr->{$method};
      $curr = $curr->{parent};
    }

    my $class = ref $invocant;
    die "unknown method $method called on CLR object";
  }
});

sub new {
  my ($class, %attrs) = @_;
  my $root = {
    new => sub {
      my ($parent, %attrs) = @_;
      $stash->bless({ %attrs, parent => $parent });
    },
    get => sub {
      my ($self, $attr) = @_;
      my $curr = $self;
      while ($curr) {
        return $curr->{$attr} if exists $curr->{$attr};
        $curr = $curr->{parent};
      }
      return undef;
    },
    set => sub {
      my ($self, $attr, $value) = @_;
      return $self->{$attr} = $value;
    },
    %attrs,
    parent => undef,
  };

  $stash->bless($root);
}

1;
