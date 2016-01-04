#!/usr/bin/env perl

use strict;
use warnings;

use Test::MockTime qw( :all );
use Test::Most;

subtest 'WhatIs' => sub {

    { package WhatIsTester; use Moo; with 'DDG::GoodieRole::WhatIs'; 1; }

    subtest 'Initialization' => sub {
        new_ok('WhatIsTester', [], 'Applied to a class');
    };

    sub basic_valid_tos {
        my $name = shift;
        return (
            "What is foo in $name?"   => 'foo',
            "what is bar in $name"    => 'bar',
            "What is $name in $name?" => "$name",
        );
    }

    sub spoken_valid_tos {
        my $name = shift;
        return (
            "How do I say foo in $name?" => 'foo',
            "How would I say bar in $name" => 'bar',
            "how to say baz in $name" => 'baz',
            "How would you say bribble in $name" => 'bribble',
            "How to say so much testing! in $name" => 'so much testing!',
        );
    }

    sub written_valid_tos {
        my $name = shift;
        return (
            "How do I write foo in $name?" => 'foo',
            "How would I write bar in $name" => 'bar',
            "how to write baz in $name" => 'baz',
            "How would you write bribble in $name" => 'bribble',
            "How to write so much testing! in $name" => 'so much testing!',
        );
    }

    sub build_value_test {
        my ($trans, $expecting_value, %forms) = @_;
        return sub {
            foreach my $key (keys %forms) {
                my $expected = $expecting_value ? $forms{$key} : undef;
                my $result = $trans->match($key);
                is($result->{'value'}, $expected, "Got an incorrect result");
            };
        };
    }

    sub get_trans_with_test {
        my $options = shift;
        my $trans = WhatIsTester::wi_translation($options);
        isa_ok($trans, 'DDG::GoodieRole::WhatIs::Base', 'wi_translation');
        return $trans;
    }

    subtest 'Translations' => sub {
        subtest 'No Groups' => sub {
            my $trans = get_trans_with_test {
                options => { to => 'Goatee' },
            };
            subtest 'Valid Queries' => build_value_test($trans, 1, basic_valid_tos('Goatee'));
            subtest 'Invalid Queries' => build_value_test($trans, 0, spoken_valid_tos('Goatee'));
        };
        subtest 'Spoken' => sub {
            my $trans = get_trans_with_test {
                options => { to => 'Lingo' },
                groups  => ['spoken'],
            };
            my %valid_tos = (basic_valid_tos('Lingo'), spoken_valid_tos('Lingo'));
            subtest 'Valid Queries' => build_value_test($trans, 1, %valid_tos);
            my %invalid_tos = ('How to say foo', 'What is Lingo');
            subtest 'Invalid Queries' => build_value_test($trans, 0, %invalid_tos);
        };
        subtest 'Written' => sub {
            my $trans = get_trans_with_test {
                options => { to => 'Lingo'},
                groups  => ['written'],
            };
            my %valid_tos = (basic_valid_tos('Lingo'), written_valid_tos('Lingo'));
            subtest 'Valid Queries' => build_value_test($trans, 1, %valid_tos);
            my %invalid_tos = ('How to say foo', 'What is Lingo', spoken_valid_tos('Lingo'));
            subtest 'Invalid Queries' => build_value_test($trans, 0, %invalid_tos);
        };
        subtest 'Written and Spoken' => sub {
            my $trans = get_trans_with_test {
                options => { to => 'Lingo' },
                groups  => ['written', 'spoken'],
            };
            my %valid_tos = (basic_valid_tos('Lingo'), written_valid_tos('Lingo'), spoken_valid_tos('Lingo'));
            subtest 'Valid Queries' => build_value_test($trans, 1, %valid_tos);
            my %invalid_tos = ('How to say foo', 'What is Lingo');
            subtest 'Invalid Queries' => build_value_test($trans, 0, %invalid_tos);
        };
        subtest 'Primary Constraint' => sub {
            my $trans = get_trans_with_test {
                options => {
                    primary => qr/\d+/,
                    to      => 'Binary',
                },
            };
            my %valid_tos = (
                'What is 11 in Binary?' => '11',
                'what is 573 in binary' => '573',
            );
            my %invalid_tos = (
                'what is five in binary?' => 'five',
                'What is hello in Binary' => 'hello',
            );
            subtest 'Valid Queries' => build_value_test($trans, 1, %valid_tos);
            subtest 'Invalid Queries' => build_value_test($trans, 0, %invalid_tos);
        };
    };

};

done_testing;
