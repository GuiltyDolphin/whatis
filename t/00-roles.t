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

#######################################################################
#                               Helpers                               #
#######################################################################

    sub build_value_test {
        my ($trans, $expecting_value, %forms) = @_;
        return sub {
            foreach my $key (keys %forms) {
                my $expected = $expecting_value ? $forms{$key} : undef;
                my $result = $trans->full_match($key);
                if (ref $expected eq 'HASH') {
                    cmp_deeply($result, superhashof($expected), "Checking details for: $key");
                } else {
                    is($result->{'primary'}, $expected, "Got an incorrect result for: $key");
                }
            };
        };
    }

    sub wi_with_test {
        my $options = shift;
        my $wi = WhatIsTester::wi_custom(%{$options});
        isa_ok($wi, 'DDG::GoodieRole::WhatIs::Matcher', 'wi_custom');
        return $wi;
    }

    sub add_valid_queries {
        my ($name, %queries) = @_;
        $wi_valid_queries{$name} = \%queries;
    }
    # Usage:
    #
    # add_option_queries 'test name' =>
    #     { opt1 => val1, ..., optn => valn }, (
    #     'query 1' => 'expected response',
    #     'query 2' => 'expected response',
    #     'query 3' => undef, # Should not get a response
    # );
    # # The 'options' are additional values that must match in the result
    # hash.
    sub add_option_queries {
        my ($name, $options, %queries) = @_;
        my %opt_queries = map {
            my $response = $queries{$_};
            if (defined $response) {
                my %opts = (%{$options}, ref $response eq 'HASH'
                    ? %{$response} : (primary => $response));
                $_ => \%opts;
            } else {
                $_ => undef;
            }
        } (keys %queries);
        $wi_valid_queries{$name} = \%opt_queries;
    }
    # Check if a query (or set of queries) should be ignored based on the
    # subtest specification.
    sub should_skip {
        my ($name, $query, $ignore_re) = @_;
        if (ref $ignore_re eq 'Regexp') {
            return $query =~ $ignore_re;
        } elsif (ref $ignore_re eq 'ARRAY') {
            foreach my $ignore (@{$ignore_re}) {
                return 1 if should_skip($name, $query, $ignore);
            }
        } else {
            return $name eq $ignore_re;
        }
        return 0;
    }

    sub modifier_test {
        my $testf = shift;
        my %wi_options = (
            to => 'Goatee',
            from => 'Gribble',
            primary => qr/[10]{4} ?[10]{4}/,
            command => qr/lower ?case|lc/i,
            postfix_command => qr/lowercased/i,
            prefix_command  => qr/lower ?case|lc/i,
            property => 'prime factor',
            singular_property => 'prime factor',
            plural_property => 'prime factors',
            unit => {
                symbol => 'm',
                word => qr/meters?/i,
            },
        );
        return sub {
            my %options = @_;
            my @use_options = @{$options{'use_options'} or []};
            my $use_groups = $options{'use_groups'};
            my @modifiers = @{$options{'modifiers'}};
            my $ignore_re = $options{'ignore'};
            my %spec_options = %{$options{'options'} || {}};
            my %valid_queries;
            foreach my $modifier (@modifiers) {
                %valid_queries = (%valid_queries, %{$wi_valid_queries{$modifier}});
            };
            my %wi_opts;
            @wi_opts{@use_options} = @wi_options{@use_options};
            %wi_opts = (%wi_opts, %spec_options);
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
                        next if should_skip($invalid, $query, $ignore_re);
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

    sub wi_custom_tests { hash_tester(\&test_custom)->(@_) }

#######################################################################
#                      Test Queries and Results                       #
#######################################################################

    add_option_queries 'what is conversion' =>
        { direction => 'to' }, (
        "What is foo in Goatee?"    => 'foo',
        "what is bar in Goatee"     => 'bar',
        "What is Goatee in Goatee?" => "Goatee",
        "What is in Goatee"         => "What is",
        "What is in Goatee?"        => undef,
    );
    add_option_queries 'what is conversion (unit)' =>
        { direction => 'to' }, (
        'what is hello meters in Goatee' => {
            unit    => 'meters',
            primary => 'hello',
        },
        'what is 5 m in Goatee' => {
            unit    => 'm',
            primary => '5',
        },
        'what is 5m in Goatee?' => {
            unit    => 'm',
            primary => '5',
        },
    );
    add_option_queries 'spoken translation' =>
        { direction => 'to', verb => 'say' }, (
        "How do I say foo in Goatee?"           => 'foo',
        "How would I say bar in Goatee"         => 'bar',
        "how to say baz in Goatee"              => 'baz',
        "How would you say bribble in Goatee"   => 'bribble',
        "How to say so much testing! in Goatee" => 'so much testing!',
    );
    add_option_queries 'written translation' =>
        { direction => 'to', verb => 'write' }, (
        "How do I write foo in Goatee?"           => 'foo',
        "How would I write bar in Goatee"         => 'bar',
        "how to write baz in Goatee"              => 'baz',
        "How would you write bribble in Goatee"   => 'bribble',
        "How to write so much testing! in Goatee" => 'so much testing!',
    );
    add_valid_queries 'prefix command' => (
        'lowercase FOO'  => {
            command        => 'lowercase',
            prefix_command => 'lowercase',
            primary        => 'FOO',
        },
        'lc bar'         => {
            command        => 'lc',
            prefix_command => 'lc',
            primary        => 'bar',
        },
        'loWer case baz' => {
            command        => 'loWer case',
            prefix_command => 'loWer case',
            primary        => 'baz',
        },
    );
    add_option_queries 'conversion in' =>
        { direction => 'to' }, (
        '1011 0101 in Goatee' => '1011 0101',
    );
    add_option_queries 'conversion from' =>
        { direction => 'from' }, (
        'hello from Gribble' => 'hello',
    );
    add_option_queries 'conversion to' =>
        { direction => 'to' }, (
        'hello to Goatee'          => 'hello',
        'convert 5 peas to Goatee' => '5 peas',
    );
    add_option_queries 'conversion to (unit)' =>
        { direction => 'to' }, (
        'hello meters to Goatee' => {
            unit    => 'meters',
            primary => 'hello',
        },
        'convert 5 m to Goatee'  => {
            unit    => 'm',
            primary => '5',
        },
        '5m to Goatee'           => {
            unit    => 'm',
            primary => '5',
        },
    );
    add_option_queries 'conversion in with translation' =>
        { direction => 'to' }, (
        'what is foo in Goatee'  => 'foo',
        'what is bar in Goatee?' => 'bar',
        'what is in Goatee'      => 'what is',
        'what is in Goatee?'     => undef,
    );
    add_option_queries 'bidirectional conversion (only to)' =>
        { direction => 'to' }, (
        'hello to Goatee'   => 'hello',
        'hello from Goatee' => 'hello',
    );
    add_valid_queries 'postfix command' => (
        'FriBble lowercased' => {
            command         => 'lowercased',
            postfix_command => 'lowercased',
            primary         => 'FriBble'
        }
    );
    add_valid_queries 'postfix command (command)' => (
        'FriBble lowercase' => {
            command         => 'lowercase',
            postfix_command => 'lowercase',
            primary         => 'FriBble'
        }
    );
    add_option_queries 'targeted property (plural)' =>
        { is_plural => 1 }, (
        'What are the prime factors of 122?' => '122',
        'prime factors of 27'                => '27',
        'what are the prime factors for 15'  => '15',
        'the prime factors of 29'            => '29',
        'what are prime factors of 29'       => undef,
    );
    add_option_queries 'targeted property (singular)' =>
        { is_plural => 0 }, (
        'What is the prime factor of 3'      => '3',
        'prime factor of 7'                  => '7',
        'what is the prime factor for 29'    => '29',
        'the prime factor of 29'             => '29',
        'what is prime factor of 29'         => undef,
    );
    add_option_queries 'language translation' =>
        { direction => 'to' }, (
        'translate hello to Goatee' => 'hello',
    );
    add_option_queries 'language translation from' =>
        { direction => 'from' }, (
        'translate hello from Gribble' => 'hello',
    );

#######################################################################
#                                Tests                                #
#######################################################################

    subtest 'Translations' => wi_custom_tests(
        'Spoken' => {
            use_options => ['to'],
            options     => {
                verb => qr/say/i,
            },
            use_groups  => ['translation', 'verb'],
            modifiers   => ['spoken translation'],
            ignore      => ['conversion in with translation'],
        },
        'Written' => {
            use_options => ['to'],
            options     => {
                verb => qr/write/i,
            },
            use_groups  => ['translation', 'verb'],
            modifiers   => ['written translation'],
            ignore      => ['conversion in with translation'],
        },
        'Written and Spoken' => {
            use_options => ['to'],
            options     => {
                verb => qr/(say|write)/i,
            },
            use_groups  => ['translation', 'verb'],
            modifiers   => ['spoken translation',
                            'written translation'],
            ignore      => ['conversion in with translation'],
        },
        'Language' => {
            use_options => ['to'],
            use_groups  => ['translation', 'language'],
            modifiers   => ['language translation'],
        },
        'Language from' => {
            use_options => ['from'],
            use_groups  => ['translation', 'language'],
            modifiers   => ['language translation from'],
        },
        'Language with conversion to' => {
            use_options => ['to'],
            use_groups  => ['translation', 'language', 'conversion'],
            modifiers   => ['language translation',
                            'conversion to'],
            ignore      => qr/^how| (in|to) /i,
        },
    );

    subtest 'Custom' => wi_custom_tests(
        'Conversion in' => {
            use_options => ['to', 'primary'],
            use_groups  => ['conversion'],
            modifiers   => ['conversion in'],
        },
        'Conversion to' => {
            use_options => ['to'],
            use_groups  => ['conversion'],
            modifiers   => ['conversion to', 'what is conversion'],
            ignore      => qr/ (to|in) /i,
        },
        'Conversion to (unit)' => {
            use_options => ['to', 'unit'],
            use_groups  => ['conversion'],
            modifiers   => ['conversion to (unit)',
                            'what is conversion (unit)'],
            ignore      => qr/ (to|in) /i,
        },
        'Conversion from' => {
            use_options => ['from'],
            use_groups  => ['conversion'],
            modifiers   => ['conversion from'],
            ignore      => qr/^translate| (to|in) /i,
        },
        'Bidirectional Conversion' => {
            use_options => ['to', 'from'],
            use_groups  => ['conversion'],
            modifiers   => ['conversion from', 'conversion to'],
            ignore      => qr/^translate| (to|in) /i,
        },
        'Command (command)' => {
            use_options => ['command'],
            use_groups  => ['command'],
            modifiers   => ['prefix command', 'postfix command (command)'],
        },
        'Command (command + postfix)' => {
            use_options => ['command', 'postfix_command'],
            use_groups  => ['command'],
            modifiers   => ['prefix command', 'postfix command'],
        },
        'Command (only prefix)' => {
            use_options => ['prefix_command'],
            use_groups  => ['command'],
            modifiers   => ['prefix command'],
        },
        'Command (only postfix)' => {
            use_options => ['postfix_command'],
            use_groups  => ['command'],
            modifiers   => ['postfix command'],
        },
        'Targeted Property' => {
            use_options => ['property'],
            use_groups  => ['property'],
            modifiers   => ['targeted property (plural)',
                            'targeted property (singular)'],
        },
        'Targeted Property (singular only)' => {
            use_options => ['singular_property'],
            use_groups  => ['property'],
            modifiers   => ['targeted property (singular)'],
        },
        'Targeted Property (plural only)' => {
            use_options => ['plural_property'],
            use_groups  => ['property'],
            modifiers   => ['targeted property (plural)'],
        },
    );

    subtest 'Expected Failures' => sub {
        subtest 'Invalid Group Combinations' => sub {
            my %invalid_group_sets = (
                "'translation'"   => ['translation'],
                "'language'"      => ['language'],
                "'verb'"          => ['verb'],
                "'language'"      => ['conversion', 'language'],
                "'foo'"           => ['language', 'translation', 'foo'],
                "'bar' and 'foo'" => ['language', 'translation', 'foo', 'bar'],
                "'bar' and 'foo'" => ['foo', 'bar'],
            );
            while (my ($group, $groups) = each %invalid_group_sets) {
                throws_ok { WhatIsTester::wi_custom->( groups => $groups ) }
                        qr/Unused groups $group/,
                        ('Should not be able to assign modifiers with groups ' . join ' and ', @{$groups});
            }
            throws_ok { WhatIsTester::wi_custom->( groups => [] ) }
                        qr/No groups specified/,
                        ('Should not accept empty groups');
        };
        subtest 'Required Options' => sub {
            my %invalid_option_sets = (
                "'to' or 'from'" => [['conversion'],
                                     ['translation', 'language']],
                "'prefix_command' or 'command' or 'postfix_command'" => [['command']],
                "'verb'" => [['translation', 'verb']],
                "'singular_property' or 'property' or 'plural_property'" => [['property']],
            );
            while (my ($req_option, $groupss) = each %invalid_option_sets) {
                foreach my $groups (@{$groupss}) {
                    throws_ok { WhatIsTester::wi_custom->( groups => $groups ) }
                            (($req_option =~ /\bor\b/) ? qr/requires at least one of the $req_option options/
                            : qr/requires the $req_option option/),
                            "Groups [@{[join ', ', @{$groups}]}] should require the $req_option option to be set";
                }
            }
        }
    }
};

done_testing;
