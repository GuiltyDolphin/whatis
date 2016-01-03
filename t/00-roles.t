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
            "What is foo in $name?",
            "what is bar in $name",
            "What is $name in $name?",
        );
    }
    sub spoken_valid_tos {
        my $name = shift;
        return (
            "How do I say foo in $name?",
            "How would I say bar in $name",
            "how to say baz in $name",
        );
    }

    sub build_match_test {
        my ($matcher, $expected, @forms) = @_;
        return sub {
            foreach my $form (@forms) {
                my $message = "$matcher @{[$expected ? 'did not match ' : 'matched ']} $form";
                is($matcher->match($form), $expected, $message);
            };
        };
    }

    subtest 'Basic Translations' => sub {
        my $btrans = WhatIsTester::wi_translation({
            to => 'Goatee',
        });
        isa_ok($btrans, 'DDG::GoodieRole::WhatIsBase', 'wi_translation');

        my @valid_tos = basic_valid_tos 'Goatee';
        my @invalid_tos = spoken_valid_tos 'Goatee';

        subtest 'Valid Tos Matching' => build_match_test($btrans, 1, @valid_tos);

        subtest 'Invalid Tos Not Matching' => build_match_test($btrans, 0, @invalid_tos);
    };

    subtest 'Match Constraints' => sub {
        my $trans = WhatIsTester::wi_translation({
            match_constraint => qr/\d+/,
            to               => 'Binary',
        });

        isa_ok($trans, 'DDG::GoodieRole::WhatIsBase', 'wi_translation');

        my @valid_tos = (
            'What is 11 in Binary?',
            'what is 573 in binary',
        );
        my @invalid_tos = (
            'what is five in binary?',
            'What is hello in Binary',
        );
        subtest 'Matches Valid Tos' => build_match_test($trans, 1, @valid_tos);
        subtest 'Not Matching Invalid Tos' => build_match_test($trans, 0, @invalid_tos);
    };
};

done_testing;
