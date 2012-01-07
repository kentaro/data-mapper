package Data::Mapper::Adapter::DBI;
use strict;
use warnings;
use parent qw(Data::Mapper::Adapter);

use Carp ();
use SQL::Maker;
use DBIx::Inspector;

sub create {
    my ($self, $table, $values) = @_;
    my ($sql, @binds) = $self->sql->insert($table, $values);

    $self->execute($sql, @binds);

    my @primary_keys = $self->inspector->primary_key;
    my $key = $primary_keys[0];

    if (scalar @primary_keys == 1 && !defined $values->{$key->name}) {
        $values->{$key->name} = $self->last_insert_id($table);
    }

    $values;
}

sub find {
    my ($self, $table, $where, $options) = @_;
    my ($sql, @binds) = $self->select($table, $where, $options);
    my $sth = $self->execute($sql, @binds);

    $sth->fetchrow_hashref;
}

sub all {
    my ($self, $table, $where, $options) = @_;
    my ($sql, @binds) = $self->select($table, $where, $options);
    my $sth = $self->execute($sql, @binds);

    my @result;
    while (my $row = $sth->fetchrow_hashref) {
        push @result, $row;
    }

    \@result;
}

sub update {
    my ($self, $table, $set, $where) = @_;
    my ($sql, @binds) = $self->sql->update($table, $set, $where);

    $self->execute($sql, @binds);
}

sub destroy {
    my ($self, $table, $where) = @_;
    my ($sql, @binds) = $self->sql->delete($table, $where);

    $self->execute($sql, @binds);
}

sub sql {
    my $self = shift;

    if (!defined $self->{sql}) {
        $self->{sql} = SQL::Maker->new(driver => $self->driver->{Driver}{Name});
    }

    $self->{sql};
}

sub inspector {
    my $self = shift;

    if (!defined $self->{inspector}) {
        $self->{inspector} = DBIx::Inspector->new(dbh => $self->driver);
    }

    $self->{inspector};
}

sub select {
    my ($self, $table, $where, $options) = @_;
    my $fields = ($options || {})->{fields} || ['*'];

    $self->sql->select($table, $fields, $where, $options);
}

sub execute {
    my ($self, $sql, @binds) = @_;
    my $sth = $self->driver->prepare($sql);
       $sth->execute(@binds);
       $sth;
}

sub last_insert_id {
    my ($self, $table) = @_;
    my $driver = $self->driver->{Driver}{Name};
    my $last_insert_id;

    if ($driver eq 'mysql') {
        $last_insert_id = $self->dbh->{mysql_insertid};
    }
    elsif ($driver eq 'Pg') {
        $last_insert_id = $self->driver->last_insert_id(
            undef, undef, undef, undef, {
                sequence => join('_', $table, 'id', 'seq')
            }
        );
    }
    elsif ($driver eq 'SQLite') {
        $last_insert_id = $self->driver->func('last_insert_rowid');
    }

    $last_insert_id;
}

!!1;
