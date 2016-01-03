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

    subtest 'Basic Translations' => sub {
        my $btrans = WhatIsTester::wi_translation({
            to => 'Goatee',
        });
        isa_ok($btrans, 'DDG::GoodieRole::WhatIsBase', 'wi_translation');

        my @valid_tos = (
            'How do I say Hello in Goatee?',
            'What is foo in Goatee',
            'translate bar to Goatee',
        );

        subtest 'Valid Tos Matching' => sub {
            foreach my $valid_to (@valid_tos) {
                is($btrans->match($valid_to), 1, "$valid_to did not match $btrans");
            };
        };

        my @invalid_tos = (
            'What is foo to Goatee',
            'How do I say bar to Goatee?',
            'What is the meaning of this?',
        );

        subtest 'Invalid Tos Not Matching' => sub {
            foreach my $invalid_to (@invalid_tos) {
                is($btrans->match($invalid_to), 0, "$invalid_to matched $btrans");
            };
        };
    }
};

done_testing;
