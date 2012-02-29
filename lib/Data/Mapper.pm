package Data::Mapper;
use 5.008001;
use strict;
use warnings;
use parent qw(Data::Mapper::Class);

our $VERSION = '0.05';

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

sub search {
    my $self = shift;
    my $name = shift;
    my $data = $self->adapter->search($name => @_);

    die 'results returned from search() method must be an ArrayRef'
        if ref $data ne 'ARRAY';

    my @result;
    push @result, $self->map_data($name, $_) for @$data;

    \@result;
}

sub update {
    my ($self, $data) = @_;
    my $result;

    if ($data->is_changed) {
        my $params = $self->mapped_params($data);

        $result = $self->adapter->update(
            $data->table => $params->{set} => $params->{where}
        );

        $data->discard_changes;
    }

    $result;
}

sub delete  {
    my ($self, $data) = @_;
    my $params = $self->mapped_params($data);

    $self->adapter->delete($data->table => $params->{where});
}

sub adapter {
    my ($self, $adapter) = @_;
    $self->{adapter} = $adapter if defined $adapter;
    $self->{adapter} || die 'You must set an adapter first';
}

### PRIVATE_METHODS ###

our %DATA_CLASSES = ();
sub data_class {
    my ($self, $name) = @_;

    $DATA_CLASSES{ref $self}{$name} ||= do {
        my $data_class = join '::', (ref $self), 'Data', $self->to_class_name($name);
        eval { Class::Load::load_class($data_class) };
        Carp::croak("no such data class: $data_class for $name") if $@;
        $data_class;
    }
}

sub to_class_name {
    my ($self, $name) = @_;
    return $name if !$name;

    my @parts = split /_/, $name;
    join '', (map { ucfirst } @parts);
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

sub mapped_params {
    my ($self, $data) = @_;
    my $table  = $data->table;
    my $schema = $self->adapter->schemata->{$table}
        or Carp::croak("no such table: $table");

    my $primary_keys = $schema->primary_keys;
    die "Data::Mapper doesn't support tables have no primary keys"
        if !scalar @$primary_keys;

    my $result = { set => $data->changes, where => {} };
    for my $key (@$primary_keys) {
        $result->{where}{$key} = $data->param($key);
    }

    Carp::croak("where clause is empty")
        if !keys %{$result->{where}};

    $result;
}

!!1;

__END__

=encoding utf8

=head1 NAME

Data::Mapper - An implementation of Data Mapper Pattern described in
PofEAA

=head1 SYNOPSIS

  # Your mapper class
  package My::Mapper;
  use parent qw(Data::Mapper);

  # Your data class related to `user` table
  package My::Mapper::Data::User;
  use parent qw(Data::Mapper::Data);

  # Then, use them
  package main;
  use Data::Mapper::Adapter::DBI;

  my $dbh     = DBI->connect($dsn, $username, $password, ...);
  my $adapter = Data::Mapper::Adapter::DBI->new({ driver => $dbh });

  # You can pass coderef as a driver factory, instead:

  my $handler = DBIx::Handler->new(...);
  my $adapter = Data::Mapper::Adapter::DBI->new({
      driver => sub { $handler->dbh }
  });

  my $mapper  = My::Mapper->new({ adapter => $adapter });

  # Create
  my $data = $mapper->create(user => { name => 'kentaro', age => 34 });
  #=> is a My::Mapper::Data::User object

  # Retrieve just one item
  $data = $mapper->find(user => { name => 'kentaro' });
  #=> is a My::Mapper::Data::User object

  $data->param('name'); #=> kentaro
  $data->param('age');  #=> 34

  # Search with some conditions
  $result = $mapper->search(user => { age => 34 }, { order_by => 'id DESC' });

  for my $data (@$result) {
      $data->param('name');
      ...
  }

  # Update
  $data->param(age => 35);
  my $sth = $mapper->update($data);
  $sth->rows; #=> 1

  # Destroy
  my $sth = $mapper->delete($data);
  $sth->rows; #=> 1

=head1 WARNING

B<This software is under the heavy development and considered ALPHA
quality now. Things might be broken, not all features have been
implemented, and APIs will be likely to change. YOU HAVE BEEN WARNED.>

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

I<Mapper> makes relations between data from a datasource, which is
typically a database, to Perl's objects, and vice versa, while keeping
them independent each other, and the mapper itself.

You can use Data::Mapper via your own mapper subclass by inheriting
it.

I<Mapper> provides the methods below:

=over 4

=item * create( I<$name> => I<\%values> )

Creates a new data, and returns it as a I<Data> object described
later.

=item * find( I<$name> => I<\%conditions> [, I<\%options>] )

Searches data according to C<\%conditions> and C<\%options>, and
returns the first one as a I<Data> object described later.

=item * search( I<$name>, I<\%conditions> [, I<\%options>] )

Searches data according to C<\%conditions> and C<\%options>, and
returns the all of them as an ArrayRef which contains each records as
a I<Data> object described later.

=item * update( I<$data> )

Updates C<$data> in the datasource.

=item * delete( I<$data> )

Deletes the C<$data> from the datasource.

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

=item * search( I<$name>, I<\%conditions> [, I<\%options>] )

Searches data according to C<\%conditions> and C<\%options>, and
returns the all of them as an ArrayRef which contains each records as
the specific form same as the one C<find()> method returns.

=item * update( I<$name>, I<\%values> [, I<\%conditions>] )

Updates data in a datasource according to C<\%values>, and
C<\%conditions>.

=item * delete( I<$name>, I<\%conditions> )

Deletes the data specified by C<\%conditions> from a datasource.

=back

The return value of C<create()>, C<find()>, C<search()> is either a
HashRef or an object which has C<as_serializable()> method to return
its contents as a HashRef.

You can adapt any data-retrieving module to Data::Model convention if
only you implement the methods described above.

=head2 Data

I<Data> represents a data model where you can define some business
logic. You must notice that I<Data> layer has no idea about what
I<Mapper> and I<Adapter> are. It just hold the data passed by
I<Mapper>

I<Mapper> returns some instance whose class inherits
I<Data::Mapper::Data> object.

  package My::Mapper::Data::User;
  use parent qw(Data::Mapper::Data);

  package My::Mapper;
  use parent qw(Data::Mapper);

  package main;
  My::Mapper;

  my $mapper = My::Mapper->new(...);
  $mapper->find(user => ...) #=> Now returns data as a My::Mapper::Data::User

=head1 AUTHOR

Kentaro Kuribayashi E<lt>kentarok@gmail.comE<gt>

=head1 REPOSITORY

=over 4

=item * GitHub

L<https://github.com/kentaro/data-mapper>

=back

=head1 SEE ALSO

=over 4

=item * Data Mapper Pattern

L<http://www.martinfowler.com/eaaCatalog/dataMapper.html>

=item * L<DBIx::ObjectMapper>

An existing Perl implementation of the pattern above. You might want
to consult it if you want much more ORM-ish features.

=item * L<DBI>

=item * L<SQL::Maker>

=back

=head1 LICENSE

Copyright (C) Kentaro Kuribayashi

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
