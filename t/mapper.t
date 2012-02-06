use t::lib::Utils;
use Test::Requires qw(DBI DBD::SQLite);

use Test::More;
use Test::Fatal;

use t::lib::Data::Mapper;
use Data::Mapper::Adapter::DBI;

my $dbh = t::lib::Utils::dbh;
   $dbh->do('create table test (id integer primary key, value text)');

my $adapter = Data::Mapper::Adapter::DBI->new({ driver => $dbh });
my $mapper  = t::lib::Data::Mapper->new({ adapter => $adapter });

subtest 'create' => sub {
    my $data = $mapper->create(test => { value => 'test create' });

    ok     $data;
    isa_ok $data, 't::lib::Data::Mapper::Data::Test';
    like   $data->param('id'),    qr/^\d+$/;
    is     $data->param('value'), 'test create';
    ok    !$data->is_changed;
};

subtest 'find' => sub {
    my $created = $mapper->create(test => { value => 'test find' });
    my $found   = $mapper->find(test => { id => $created->{id} });

    ok        $found;
    isa_ok    $found, 't::lib::Data::Mapper::Data::Test';
    is_deeply $created, $found;
    ok        !$found->is_changed;

    note 'when not found';
    my $ret = $mapper->find(test => { id => 'not found key' });
    ok !$ret;
};

subtest 'search' => sub {
    my $created1 = $mapper->create(test => { value => 'test search' });
    my $created2 = $mapper->create(test => { value => 'test search' });

    my $data = $mapper->search(test => {
        value => 'test search'
    }, {
        order_by => 'id desc'
    });

    ok $data;
    is ref $data, 'ARRAY';
    is scalar @$data, 2;

    for my $record (@$data) {
        isa_ok $record, 't::lib::Data::Mapper::Data::Test';
        ok    !$record->is_changed;
    }

    is_deeply $data, [$created2, $created1];
};

subtest 'update' => sub {
    my $data = $mapper->create(test => { value => 'test update' });

    is $data->param('value'), 'test update';
    $data->param(value => 'test updated');

    my $ret = $mapper->update(test => $data->changes, { id => $data->{id} });

    ok     $ret;
    isa_ok $ret, 'DBI::st';
    is     $ret->rows, 1;

    my $updated = $mapper->find(test => { id => $data->{id} });

    ok $updated;
    is $updated->param('value'), 'test updated';
};

subtest 'delete' => sub {
    my $data = $mapper->create(test => { value => 'test delete' });

    ok $data;

    my $ret = $mapper->delete(test => { id => $data->{id} });

    ok $ret;
    isa_ok $ret, 'DBI::st';
    is     $ret->rows, 1;

    my $deleted = $mapper->find(test => { id => $data->{id} });

    ok !$deleted;
};

subtest 'data_class' => sub {
    my $class1 = $mapper->data_class('test');
    my $class2 = $mapper->data_class('nothing');

    is $class1, 't::lib::Data::Mapper::Data::Test';
    is $class2, 'Data::Mapper::Data';
};

subtest 'map_data' => sub {
    note 'when a HashRef passed';
    {
        my $data = $mapper->map_data(test => { foo => 'test' });

        ok     $data;
        isa_ok $data, 't::lib::Data::Mapper::Data::Test';
        is     $data->param('foo'), 'test';
    }

    note 'croaks when an normal object passed';
    {
        like exception { $mapper->map_data(test => (bless {}, 't::Dummy')) },
             qr/^blessed data/;
    }

    note 'but not croaks if the object has as_serializable() method';
    {
        my $data = $mapper->map_data(test => Data::Mapper::Class->new({
            foo => 'test'
        }));

        ok     $data;
        isa_ok $data, 't::lib::Data::Mapper::Data::Test';
        is     $data->param('foo'), 'test';
    }
};

done_testing;
