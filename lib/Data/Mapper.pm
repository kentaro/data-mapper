package Data::Mapper;
use 5.008001;
use strict;
use warnings;
use parent qw(Data::Mapper::Class);

our $VERSION = '0.01';

use Carp         ();
use Scalar::Util ();
use Class::Load  ();

use Data::Mapper::Data;

sub create {
    my $self = shift;
    my $name = shift;
    my $data = $self->adapter->create($name => @_);

    $self->map_data($name, $data);
}

sub find {
    my $self = shift;
    my $name = shift;
    my $data = $self->adapter->find($name => @_);

    $data && $self->map_data($name, $data);
}

sub all {
    my $self = shift;
    my $name = shift;
    my $data = $self->adapter->all($name => @_);

    die 'results returned from all() method must be an ArrayRef'
        if ref $data ne 'ARRAY';

    my @result;
    push @result, $self->map_data($name, $_) for @$data;

    \@result;
}

sub update {
    my $self = shift;
    my $name = shift;

    $self->adapter->update($name => @_);
}

sub destroy  {
    my $self = shift;
    my $name = shift;

    $self->adapter->destroy($name => @_);
}

sub adapter {
    my ($self, $adapter) = @_;
    $self->{adapter} = $adapter if defined $adapter;
    $self->{adapter} || die 'You must set an adapter first';
}

my %DATA_CLASSES = ();
sub data_class {
    my ($self, $name) = @_;

    $DATA_CLASSES{$name} ||= do {
        my $data_class = join '::', (ref $self), 'Data', ucfirst lc $name;
        warn $data_class;

        eval { Class::Load::load_class($data_class) };
        $data_class = 'Data::Mapper::Data' if $@;
        $data_class;
    }
}

sub map_data {
    my ($self, $name, $data) = @_;
    my $data_class = $self->data_class($name);

    if (Scalar::Util::blessed($data)) {
        Carp::croak('blessed data must have as_serializable method')
            if !$data->can('as_serializable');

        $data = $data->as_serializable;
    }

    $data_class->new($data);
}

!!1;

__END__

=encoding utf8

=head1 NAME

Data::Mapper - An implementation of Data Mapper Pattern described in
PofEAA

=head1 SYNOPSIS

  use Data::Mapper;
  use Data::Mapper::Adapter::DBI;

  my $dbh     = DBI->connect($dsn, $username, $password, ...);
  my $adapter = Data::Mapper::Adapter::DBI->new({ driver => $dbh });
  my $mapper  = Data::Mapper->new({ adapter => $adapter });

  # Create
  my $data = $mapper->create(user => { name => 'kentaro', age => 34 });

  # Retrieve just one item
  $data = $mapper->find(user => { name => 'kentaro' });
  $data->param('name'); #=> kentaro
  $data->param('age');  #=> kentaro

  # Retrieve all with some conditions
  $result = $mapper->all(user => { age => 34 }, { order_by => 'id DESC' });

  for my $data (@$result) {
      $data->param('name');
      ...
  }

  # Update
  $data->param(age => 35);
  my $sth = $mapper->update(user => $data->changes, { name => $data->param('name') });
  $sth->rows; #=> 1

  # Destroy
  my $sth = $mapper->destroy(user => { name => $data->param('name') });
  $sth->rows; #=> 1

=head1 DESCRIPTION

Data::Mapper is an implementation of Data Mapper Pattern described in
PofEAA, written by Martin Fowler, and is kind of a ORM, but not
limited only to it, that is, this module just relates some data to
another; for example, data from a database to Perl's objects.

=head1 Data::Mapper Convention

This module, actually, merely defines a simple convention how to make
relations between some data to another, and now has only one adapter
implementation: Data::Mapper::Adapter::DBI.

=head2 Mapper

I<Mapper> makes relations between data from somewhere, typically from
a database, to Perl's objects, and vice versa, while keeping them
independent of each other and the mapper itself.

You can use Data::Mapper directly or make your own mapper by
inheriting it.

I<Mapper> provides the methods below:

=over 4

=item * create( I<$name>, I<\%values> )

Creates a new data, and returns it as a I<Data> object described
later.

=item * find( I<$name>, I<\%conditions> [, I<\%options>] )

Searches data according to C<\%conditions> and C<\%options>, and
returns the first one as a I<Data> object described later.

=item * all( I<$name>, I<\%conditions> [, I<\%options>] )

Searches data according to C<\%conditions> and C<\%options>, and
returns the all of them as an ArrayRef which contains each records as
a I<Data> object described later.

=item * update( I<$name>, I<\%values> [, I<\%conditions>] )

Updates data according to C<\%values>, and C<\%conditions>.

=item * destroy( I<$name>, I<\%conditions> )

Deletes the data specified by C<\%conditions>.

=back

=head2 Adapter

I<Adapter> does CRUD operations against a datasource (database,
memcached, etc.). It must implement some methods according to the
convention.

I<Adapter> must implements the methods below:

=over 4

=item * create( I<$name>, I<\%values> )

Creates a new data, and returns it as a specific form described later.

=item * find( I<$name>, I<\%conditions> [, I<\%options>] )

Searches data according to C<\%conditions> and C<\%options>, and
returns the first one as a specific form described later.

=item * all( I<$name>, I<\%conditions> [, I<\%options>] )

Searches data according to C<\%conditions> and C<\%options>, and
returns the all of them as an ArrayRef which contains each records as
the specific form same as the one C<find()> method returns.

=item * update( I<$name>, I<\%values> [, I<\%conditions>] )

Updates data in a datasource according to C<\%values>, and
C<\%conditions>.

=item * destroy( I<$name>, I<\%conditions> )

Deletes the data specified by C<\%conditions> from a datasource.

=back

The return value of C<create()>, C<find()>, C<all()> is either a
HashRef or an object which has C<as_serializable()> method to return
its contents as a HashRef.

You can adapt any data-retrieving module to Data::Model convention if
only you implement the methods described above.

=head2 Data

I<Data> represents a model where you can define some business
logic. You must notice that I<Data> layer has no idea about what
I<Mapper> and I<Adapter> are. It just hold the data passed by
I<Mapper>

I<Data> object, in fact, can be any plain hash-based object although
this distribution provides I<Data::Mapper::Data> for
convenience. I<Data> object must:

=over 4

=item Have a C<new()> method which takes a HashRef as an argument

=item Be a plain hash-based object

=back

I<Mapper> returns data as a I<Data::Mapper::Data> object by
default. You can define your own I<Data> object by inheriting
I<Data::Mapper>.

  package My::Mapper::Data::User;
  use parent qw(Data::Mapper::Data);

  package My::Mapper;
  use parent qw(Data::Mapper); #=> It's not necessarilly required as explained above

  package main;
  My::Mapper;

  my $mapper->new(...);
  $mapper->find(user => ...) #=> Now returns data as a My::Mapper::Data::User

I<Data::Mapper::Data>-based object has one might-be-useful methods:
C<is_changed()> and C<changes()>. It's so when you changed the values
in the object and attempt to sync them into a datasource.

  my $data = $mapper->find(user => { name => 'kentaro' });
  $data->param(age => 35);

  # Dispatches changing operation if data is changed
  $data->is_changed &&
  $mapper->update(user => $data->changes, { name => $data->param('name') });

=head1 AUTHOR

Kentaro Kuribayashi E<lt>kentarok@gmail.comE<gt>

=head1 SEE ALSO

=over 4

=item * Data Mapper Pattern

L<http://www.martinfowler.com/eaaCatalog/dataMapper.html>

=item * L<DBIx::ObjectMapper>

An existing Perl implementation of the pattern above. You might want
to consult it if you want much more ORM-ish features.

=back

=head1 LICENSE

Copyright (C) Kentaro Kuribayashi

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
