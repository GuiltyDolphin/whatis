package WhatIs::Matcher;
# ABSTRACT: Object that generates matchers for various forms of query.

use strict;
use warnings;

use WhatIs::Modifiers qw(get_modifiers);
use WhatIs::Modifier;

use Moo;

# Hash from regular expressions to modifiers.
has '_modifier_regexes' => (
    is => 'ro',
    isa => sub { die "$_[0] is not a HASH reference" unless ref $_[0] eq 'HASH' },
    default => sub { {} },
);

# Determine which modifiers get applied to the matcher.
has 'groups' => (
    is => 'ro',
    isa => sub { die "$_[0] is not an ARRAY reference" unless ref $_[0] eq 'ARRAY' },
    default => sub { [] },
);

# Group-specific options.
has 'options' => (
    is => 'ro',
    isa => sub { die "$_[0] is not a HASH reference" unless ref $_[0] eq 'HASH' },
    default => sub { {} },
);

sub _run_matches {
    my ($re_sub, $self, $to_match) = @_;
    my %reg_map = %{$self->_modifier_regexes};
    my @sorted_re = sort {
        $reg_map{$b}->priority <=> $reg_map{$a}->priority
    } (keys %reg_map);
    foreach my $re (@sorted_re) {
        my $modifier = $reg_map{$re};
        if (my $res = _run_match($to_match, $re_sub->($re), $modifier)) {
            return $res;
        };
    }
    return;
}

sub match { _run_matches(sub { $_[0] }, @_) };

sub full_match { _run_matches(sub { qr/^$_[0]$/ }, @_) }

sub BUILD {
    my $self = shift;
    my @modifiers = get_modifiers($self->groups);
    foreach my $modifier (@modifiers) {
        $modifier->parse_options(%{$self->options});
        my $re = $modifier->generate_regex();
        $self->{_modifier_regexes}->{$re} = $modifier;
    };
}

sub _run_match {
    my ($to_match, $re, $modifier) = @_;
    if ($to_match =~ /$re/) {
        my %results = $modifier->build_result(%+);
        return \%results;
    }
    return;
}

1;

__END__

=head1 NAME

WhatIs::Matcher - generate matchers for various forms of query

=head1 AUTHOR

Ben Moon aka GuiltyDolphin E<lt>softwareE<64>guiltydolphin.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2016 DuckDuckGo, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Modification Copyright (C) 2018  Ben Moon

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

=cut
