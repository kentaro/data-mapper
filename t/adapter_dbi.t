use t::lib::Utils;
use Test::Requires qw(DBI DBD::SQLite);

use Test::More;
use Test::Fatal;

use Data::Mapper::Adapter::DBI;

my $dbh = t::lib::Utils::dbh;
   $dbh->do('create table test (id integer primary key, value text)');

my $adapter = Data::Mapper::Adapter::DBI->new({ driver => $dbh });

subtest 'create' => sub {
    my $data = $adapter->create(test => { value => 'test create' });

    ok   $data;
    is   ref $data, 'HASH';
    like $data->{id}, qr/^\d+$/;
    is   $data->{value}, 'test create';
};

subtest 'find' => sub {
    my $created = $adapter->create(test => { value => 'test find' });
    my $found   = $adapter->find(test => { id => $created->{id} });

    ok        $found;
    is        ref $found, 'HASH';
    is_deeply $created, $found;
};

subtest 'all' => sub {
    my $created1 = $adapter->create(test => { value => 'test all' });
    my $created2 = $adapter->create(test => { value => 'test all' });

    my $data = $adapter->all(test => {
        value => 'test all'
    }, {
        order_by => 'id desc'
    });

    ok $data;
    is ref $data, 'ARRAY';
    is scalar @$data, 2;
    is_deeply $data, [$created2, $created1];
};

subtest 'update' => sub {
    my $created = $adapter->create(test => { value => 'test update' });

    ok $created;
    is $created->{value}, 'test update';

    my $ret = $adapter->update(test => { value => 'test updated' }, { id => $created->{id} });

    ok     $ret;
    isa_ok $ret, 'DBI::st';
    is     $ret->rows, 1;

    my $updated = $adapter->find(test => { id => $created->{id} });

    ok $updated;
    is $updated->{value}, 'test updated';
};

subtest 'destroy' => sub {
    my $created = $adapter->create(test => { value => 'test destroy' });

    ok $created;
    is $created->{value}, 'test destroy';

    my $ret = $adapter->destroy(test => { id => $created->{id} });

    ok $ret;
    isa_ok $ret, 'DBI::st';
    is     $ret->rows, 1;

    my $data = $adapter->find(test => { id => $created->{id} });

    ok !$data;
};

done_testing;
