package WhatIs::Modifiers;
# ABSTRACT: Defines the possible modifiers that can be used.

use strict;
use warnings;

use Moo;

use List::Util qw(all first);

use WhatIs::Expression qw(:EXPR);
use WhatIs::Modifier;

BEGIN {
    require Exporter;

    our @ISA = qw(Exporter);
    our @EXPORT_OK = qw(get_modifiers);
}

my @modifier_specs;

#######################################################################
#                          Modifier Helpers                           #
#######################################################################

sub new_modifier_spec {
    my ($name, $options) = @_;
    my %opts = (name => $name, _regex_generator => $options->{regex_sub});
    %opts = (%opts, %$options);
    my $modifier_spec = \%opts;
    push @modifier_specs, $modifier_spec;
}

sub new_modifier {
    my $modifier_spec = shift;
    return WhatIs::Modifier->new(%$modifier_spec);
}

#######################################################################
#                              Modifiers                              #
#######################################################################

new_modifier_spec 'verb translation' => {
    required_groups  => ['translation', 'verb'],
    option_defaults => {
        primary => qr/.+/,
    },
    regex_sub => \&translation_generic,
};
new_modifier_spec 'conversion' => {
    required_groups => ['conversion'],
    option_defaults => {
        primary => qr/.+/,
    },
    priority => 3,
    regex_sub => \&conversion_generic,
};
new_modifier_spec 'command' => {
    required_groups  => ['command'],
    option_defaults => {
        primary => qr/.+/,
    },
    regex_sub => \&command_generic,
};
new_modifier_spec 'property' => {
    required_groups  => ['property'],
    option_defaults => {
        primary => qr/.+/,
    },
    regex_sub => \&property,
};
new_modifier_spec 'language translation' => {
    required_groups  => ['translation', 'language'],
    option_defaults => {
        primary => qr/.+/,
    },
    regex_sub => \&language_translation,
};

#######################################################################
#        Regular Expressions and Regular Expression Generators        #
#######################################################################

sub translation_generic {
    my $options = shift;
    expr($options)
        ->how_to->opt('verb')->opt('primary')->in->opt('to')
        ->question
    ->regex;
}

sub conversion_generic {
    my $options = shift;
    expr($options)->or(
        expr($options)->or(
            expr($options)
                ->optional(qr/convert/i)
                ->opt('primary')
                ->to->opt('to'),
            expr($options)->or(
                expr($options)
                    ->words(qr/what is/i)
                    ->opt('primary')
                    ->in->opt('to')->question,
                expr($options)
                    ->opt('primary')
                    ->in->opt('to'),
            ),
        ),
        expr($options)
            ->opt('primary')->from->opt('from')
    )->regex;
}

sub command_generic {
    my $options = shift;
    expr($options)->or(
        expr($options)
            ->prefer_opt('prefix_command', 'command')
            ->opt('primary'),
        expr($options)
            ->opt('primary')
            ->prefer_opt('postfix_command', 'command'),
    )->regex;
}

sub language_translation {
    my $options = shift;
    expr($options)
        ->words(qr/translate/i)->opt('primary')->spaced->or(
            expr($options)->to->opt('to'),
            expr($options)->from->opt('from'),
        )->regex;
}

sub pluralize {
    my %v = %{$_[0]};
    $v{match} .= 's';
    return \%v;
}

sub property {
    my $options = shift;
    expr($options)->or(
        named('_singular', $options)
            ->optional_when_before(qr/what is/i, qr/the/i)
            ->prefer_opt('singular_property', 'property'),
        named('_plural', $options)
            ->optional_when_before(qr/what are/i, qr/the/i)
            ->prefer_opt('plural_property', ['property', \&pluralize])
    )->words(qr/(of|for)/i)->opt('primary')->question
    ->regex;
}

#######################################################################
#                         External Interface                          #
#######################################################################

sub sublist {
    my ($small, $parent) = @_;
    my @small  = @{$small};
    my @parent = @{$parent};
    return all { my $x = $_; first { $x eq $_ } @parent } @small;
}

sub get_modifiers {
    my $groups = shift;
    die "No groups specified" unless @$groups;
    my @applicable_modifiers = ();
    my %used_groups = map { $_ => 0 } @$groups;
    foreach my $modifier (@modifier_specs) {
        my $required_groups = $modifier->{required_groups};
        if (sublist($required_groups, $groups)) {
            push @applicable_modifiers, new_modifier($modifier);
            map { $used_groups{$_} = 1 } @$required_groups;
        }
    };
    my @unused = sort grep { $used_groups{$_} eq 0 } (keys %used_groups);
    die "Unused groups " . join(' and ', map { "'$_'" } @unused)
        if @unused;
    return @applicable_modifiers;
}

1;

__END__

=head1 NAME

WhatIs::Modifiers - preset modifiers

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

Modification Copyright (C) 2018, 2021  Ben Moon

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
