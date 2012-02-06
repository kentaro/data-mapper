use t::lib::Utils;

use Test::More;
use Test::Fatal;

use Data::Mapper::Adapter;

subtest 'driver' => sub {
    my $adapter = Data::Mapper::Adapter->new;
    ok exception { $adapter->driver };
    $adapter->driver('some driver implementation');
    ok !exception { $adapter->driver };
};

package t::Data::Mapper::Adapter;
use parent qw(Data::Mapper::Adapter);
package main;

subtest 'subclass' => sub {
    my $adapter = t::Data::Mapper::Adapter->new;

    like exception { $adapter->$_ }, qr/^$_\(\) method/
        for qw(create find search update delete schemata);
};

done_testing;
