#!/usr/bin/env perl

use strict;
use warnings;

use Test::MockTime qw( :all );
use Test::Most;

my %wi_valid_queries = ();
subtest 'WhatIs' => sub {

    { package WhatIsTester; use Moo; with 'DDG::GoodieRole::WhatIs'; 1; }

    subtest 'Initialization' => sub {
        new_ok('WhatIsTester', [], 'Applied to a class');
    };

    sub build_value_test {
        my ($trans, $expecting_value, %forms) = @_;
        return sub {
            foreach my $key (keys %forms) {
                my $expected = $expecting_value ? $forms{$key} : undef;
                my $result = $trans->full_match($key);
                is($result->{'value'}, $expected, "Got an incorrect result for: $key");
            };
        };
    }

    sub entry_builder {
        my $func = shift;
        return sub {
            my $options = shift;
            no strict 'refs';
            my $f = \&{"WhatIsTester::$func"};
            my $wi = $f->(%{$options});
            isa_ok($wi, 'DDG::GoodieRole::WhatIs::Base', "$func");
            return $wi;
        };
    }
    sub wi_with_test { entry_builder('wi_custom')->(@_) };
    sub get_trans_with_test { entry_builder('wi_translation')->(@_) };

    sub add_valid_queries {
        my ($name, %queries) = @_;
        $wi_valid_queries{$name} = \%queries;
    }

    sub modifier_test {
        my $testf = shift;
        my %wi_options = (
            to => 'Goatee',
            from => 'Gribble',
            primary => qr/[10]{4} ?[10]{4}/,
            command => qr/lower ?case|lc/i,
            postfix_command => qr/lowercased/i,
            property => 'prime factor',
        );
        return sub {
            my %options = @_;
            my @use_options = @{$options{'use_options'} or []};
            my $use_groups = $options{'use_groups'};
            my @modifiers = @{$options{'modifiers'}};
            my $ignore_re = $options{'ignore'};
            my %valid_queries;
            foreach my $modifier (@modifiers) {
                %valid_queries = (%valid_queries, %{$wi_valid_queries{$modifier}});
            };
            my %wi_opts;
            @wi_opts{@use_options} = @wi_options{@use_options};
            my $wi = $testf->({
                groups => $use_groups,
                options => \%wi_opts,
            });
            subtest 'Valid Queries' => build_value_test($wi, 1, %valid_queries);
            my %invalid_queries = %{$options{'invalid_queries'}} if defined $options{'invalid_queries'};
            foreach my $invalid (keys %wi_valid_queries) {
                next if grep { $_ eq $invalid } @modifiers;
                if (defined $ignore_re) {
                    my %to_add;
                    foreach my $query (keys %{$wi_valid_queries{$invalid}}) {
                        next if $query =~ $ignore_re;
                        $to_add{$query} = $wi_valid_queries{$invalid}->{$query};
                    };
                    %invalid_queries = (%invalid_queries, %to_add);
                } else {
                    %invalid_queries = (%invalid_queries, %{$wi_valid_queries{$invalid}});
                };
            };
            subtest 'Invalid Queries' => build_value_test($wi, 0, %invalid_queries);
        };
    }
    sub test_custom { modifier_test(\&wi_with_test)->(@_) };
    sub test_translation { modifier_test(\&get_trans_with_test)->(@_) };

    add_valid_queries 'what is conversion' => (
        "What is foo in Goatee?"    => 'foo',
        "what is bar in Goatee"     => 'bar',
        "What is Goatee in Goatee?" => "Goatee",
    );
    add_valid_queries 'spoken translation' => (
        "How do I say foo in Goatee?"           => 'foo',
        "How would I say bar in Goatee"         => 'bar',
        "how to say baz in Goatee"              => 'baz',
        "How would you say bribble in Goatee"   => 'bribble',
        "How to say so much testing! in Goatee" => 'so much testing!',
    );
    add_valid_queries 'written translation' => (
        "How do I write foo in Goatee?"           => 'foo',
        "How would I write bar in Goatee"         => 'bar',
        "how to write baz in Goatee"              => 'baz',
        "How would you write bribble in Goatee"   => 'bribble',
        "How to write so much testing! in Goatee" => 'so much testing!',
    );
    add_valid_queries 'prefix imperative' => (
        'lowercase FOO'  => 'FOO',
        'lc bar'         => 'bar',
        'loWer case baz' => 'baz',
    );
    add_valid_queries 'meaning' => (
        'What is the meaning of bar' => 'bar',
        'What does foobar mean?'     => 'foobar',
    );
    add_valid_queries 'base conversion' => (
        '1011 0101 in Goatee' => '1011 0101',
        '11111111 to Goatee'  => '11111111',
    );
    add_valid_queries 'conversion from' => (
        'hello from Gribble' => 'hello',
    );
    add_valid_queries 'conversion to' => (
        'hello to Goatee' => 'hello',
    );
    add_valid_queries 'bidirectional conversion (only to)' => (
        'hello to Goatee'   => 'hello',
        'hello from Goatee' => 'hello',
    );
    add_valid_queries 'postfix imperative' => (
        'FriBble lowercased' => 'FriBble',
    );
    add_valid_queries 'targeted property' => (
        'What are the prime factors of 122?' => '122',
        'What is the prime factor of 3'      => '3',
        'prime factors of 27'                => '27',
        'prime factor of 7'                  => '7',
        'what is the prime factor for 29'    => '29',
        'what are the prime factors for 15'  => '15',
    );
    add_valid_queries 'language translation' => (
        'translate hello to Goatee' => 'hello',
    );

    sub hash_tester {
        my $hashf = shift;
        return sub {
            my %tests = @_;
            return sub {
                while (my ($test_name, $params) = each %tests) {
                    subtest $test_name => sub { $hashf->(%{$params}) };
                };
            };
        };
    }

    sub wi_translation_tests { hash_tester(\&test_translation)->(@_) }

    subtest 'Translations' => wi_translation_tests(
        'What is conversion' => {
            use_options => ['to'],
            modifiers => ['what is conversion'],
        },
        'Spoken' => {
            use_options => ['to'],
            use_groups => ['spoken'],
            modifiers => ['spoken translation', 'what is conversion'],
        },
        'Written' => {
            use_options => ['to'],
            use_groups => ['written'],
            modifiers => ['written translation', 'what is conversion'],
        },
        'Written and Spoken' => {
            use_options => ['to'],
            use_groups => ['written', 'spoken'],
            modifiers => ['spoken translation',
                          'written translation',
                          'what is conversion'],
        },
        'Language' => {
            use_options => ['to'],
            use_groups => ['language'],
            modifiers => ['language translation', 'what is conversion'],
        },
    );
    sub wi_custom_tests { hash_tester(\&test_custom)->(@_) }

    subtest 'Custom' => wi_custom_tests(
        'Meaning' => {
            use_groups => ['meaning'],
            modifiers => ['meaning'],
        },
        'Base Conversion' => {
            use_options => ['to', 'primary'],
            use_groups => ['conversion'],
            modifiers => ['base conversion'],
        },
        'Conversion to' => {
            use_options => ['to'],
            use_groups  => ['conversion', 'to'],
            modifiers   => ['conversion to'],
            ignore      => qr/ (to|in) /i,
        },
        'Conversion from' => {
            use_options => ['from'],
            use_groups  => ['conversion', 'from'],
            modifiers   => ['conversion from'],
            ignore      => qr/ (to|in) /i,
        },
        'Bidirectional Conversion' => {
            use_options => ['to', 'from'],
            use_groups  => ['bidirectional', 'conversion'],
            modifiers   => ['conversion from', 'conversion to'],
            ignore      => qr/ (to|in) /i,
        },
        'Bidirectional Conversion (only to)' => {
            use_options => ['to'],
            use_groups  => ['bidirectional', 'conversion'],
            modifiers   => ['base conversion', 'bidirectional conversion (only to)'],
            ignore      => qr/ (to|in) /i,
        },
        'Prefix Imperative' => {
            use_options => ['command'],
            use_groups => ['prefix', 'imperative'],
            modifiers => ['prefix imperative'],
        },
        'Postfix + Prefix Imperative' => {
            use_options => ['command', 'postfix_command'],
            use_groups => ['postfix', 'prefix', 'imperative'],
            modifiers => ['prefix imperative', 'postfix imperative'],
        },
        'Targeted Property' => {
            use_options => ['property'],
            use_groups  => ['property'],
            modifiers   => ['targeted property'],
        },
    );
};

done_testing;
