package Data::Mapper::Adapter;
use strict;
use warnings;
use parent qw(Data::Mapper::Class);

sub driver {
    my ($self, $driver) = @_;
    $self->{driver} = $driver if defined $driver;
    $self->{driver} || die 'You must set a driver first';
}

sub create   { die 'create() method must be implemented by subclass'  }
sub find     { die 'find() method must be implemented by subclass'    }
sub all      { die 'all() method must be implemented by subclass'     }
sub update   { die 'update() method must be implemented by subclass'  }
sub destroy  { die 'destroy() method must be implemented by subclass' }

!!1;
