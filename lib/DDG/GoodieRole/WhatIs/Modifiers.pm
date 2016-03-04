package DDG::GoodieRole::WhatIs::Modifiers;
# ABSTRACT: Defines the possible modifiers that can be used
# with the 'WhatIs' GoodieRole.

use strict;
use warnings;

use Moo;
use DDG::GoodieRole::WhatIs::Modifier;
use List::MoreUtils qw(any);
use DDG::GoodieRole::WhatIs::Expression qw(expr named);

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
    return DDG::GoodieRole::WhatIs::Modifier->new(%$modifier_spec);
}

# Create a helper for matching against modifier group
# specifications.
#
# $should_return should indicate whether the inverse of $default
# should be returned if the current specifier matches.
#
# $default is returned if $should_return is never true.
sub gspec_helper {
    my ($default, $should_return) = @_;
    return sub {
        my @group_specs = @_;
        return sub {
            my @groups = @_;
            foreach my $gspec (@group_specs) {
                if (ref $gspec eq 'CODE') {
                    return (not $default) if
                        $should_return->($gspec->(@groups));
                } else {
                    return (not $default) if
                        $should_return->(
                            any { $_ eq $gspec} @groups);
                }
            }
            return $default;
        }
    }
}

# True if any of the group specifiers match.
sub any_of { gspec_helper(0, sub {     $_[0] })->(@_) }

# True if all of the group specifiers match.
sub all_of { gspec_helper(1, sub { not $_[0] })->(@_) }

# True if none of the group specifiers match.
sub none_of { gspec_helper(1, sub {     $_[0] })->(@_) }

#######################################################################
#                              Modifiers                              #
#######################################################################

new_modifier_spec 'written translation' => {
    required_groups  => all_of('translation', 'written'),
    option_defaults => {
        primary => qr/.+/,
    },
    regex_sub => \&written_translation,
};
new_modifier_spec 'spoken translation' => {
    required_groups  => all_of('translation', 'spoken'),
    option_defaults => {
        primary => qr/.+/,
    },
    regex_sub => \&spoken_translation,
};
new_modifier_spec 'what is conversion' => {
    required_groups  => all_of('translation',
                        any_of(none_of('from'), 'to')),
    option_defaults => {
        primary => qr/.+/,
    },
    regex_sub => \&whatis_translation,
};
new_modifier_spec 'meaning' => {
    required_groups  => all_of('meaning'),
    option_defaults => {
        primary => qr/.+/,
    },
    regex_sub => \&meaning,
};
new_modifier_spec 'conversion to' => {
    required_groups  => all_of('conversion',
                            any_of('to', 'bidirectional')),
    option_defaults => {
        primary => qr/.+/,
        unit    => qr//,
    },
    priority         => 3,
    regex_sub => \&conversion_to,
};
new_modifier_spec 'conversion from' => {
    required_groups  => all_of('conversion',
                            any_of('bidirectional', 'from')),
    option_defaults => {
        primary => qr/.+/,
    },
    priority         => 3,
    regex_sub => \&conversion_from,
};
new_modifier_spec 'conversion in' => {
    required_groups  => all_of('conversion'),
    option_defaults  => {
        primary => qr/.+/,
    },
    priority         => 3,
    regex_sub => \&conversion_in,
};
new_modifier_spec 'prefix imperative' => {
    required_groups  => all_of('prefix', 'imperative'),
    option_defaults => {
        primary => qr/.+/,
    },
    regex_sub => \&prefix_imperative,
};
new_modifier_spec 'postfix imperative' => {
    required_groups  => all_of('postfix', 'imperative'),
    option_defaults => {
        primary => qr/.+/,
    },
    regex_sub => \&postfix_imperative,
};
new_modifier_spec 'targeted property' => {
    required_groups  => all_of('property'),
    option_defaults => {
        primary => qr/.+/,
    },
    regex_sub => \&targeted_property,
};
new_modifier_spec 'language translation' => {
    required_groups  => all_of('translation', 'language', none_of('from')),
    option_defaults => {
        primary => qr/.+/,
    },
    regex_sub => \&language_translation,
};
new_modifier_spec 'language translation from' => {
    required_groups  => all_of('translation', 'language',
                            any_of('from', 'bidirectional')),
    option_defaults => {
        primary => qr/.+/,
    },
    regex_sub => \&language_translation_from,
};

#######################################################################
#        Regular Expressions and Regular Expression Generators        #
#######################################################################

sub written_translation {
    my $options = shift;
    expr($options)
        ->how_to(qr/write/i)->opt('primary')->unit->in->opt('to')->question
        ->regex;
}

sub spoken_translation {
    my $options = shift;
    expr($options)
        ->how_to(qr/say/i)->opt('primary')->unit->in->opt('to')->question
        ->regex;
}
sub whatis_translation {
    my $options = shift;
    expr($options)
        ->words(qr/what is/i)->opt('primary')->unit->in->opt('to')->question
        ->regex;
}

sub meaning {
    my $options = shift;
    expr($options)->or(
        expr($options)
            ->words(qr/what is the meaning of/i)->opt('primary'),
        expr($options)
            ->words(qr/what does/i)->opt('primary')->words(qr/mean/i)
    )->question
    ->regex;
}

sub conversion_to {
    my $options = shift;
    expr($options)
        ->optional(qr/convert/i)->opt('primary')->unit->to->opt('to')
        ->regex;
}

sub conversion_from {
    my $options = shift;
    expr($options)
        ->opt('primary')->unit->from->opt('from')
        ->regex;
}

sub conversion_in {
    my $options = shift;
    expr($options)
        ->opt('primary')->unit->in->prefer_opt('to', 'from')
        ->regex;
}

sub prefix_imperative {
    my $options = shift;
    expr($options)
        ->prefer_opt('prefix_command', 'command')->opt('primary')
        ->regex;
}

sub postfix_imperative {
    my $options = shift;
    expr($options)
        ->opt('primary')->prefer_opt('postfix_command', 'command')
        ->regex;
}

sub language_translation {
    my $options = shift;
    expr($options)
        ->words(qr/translate/i)->opt('primary')->to->opt('to')
        ->regex;
}

sub language_translation_from {
    my $options = shift;
    expr($options)
        ->words(qr/translate/i)->opt('primary')->from->opt('from')
        ->regex;
}

sub pluralize {
    my %options = @_;
    return $options{singular_property} . 's'
        if defined $options{singular_property};
    return $options{property} . 's'
        if defined $options{property};
}

sub targeted_property {
    my $options = shift;
    expr($options)->or(
        named('_singular', $options)
            ->optional(qr/what is/i)
            ->optional(qr/the/i)
            ->prefer_opt('singular_property', 'property'),
        named('_plural', $options)
            ->optional(qr/what are/i)
            ->optional(qr/the/i)
            ->prefer_opt('plural_property', \&pluralize)
        )->words(qr/(of|for)/i)->opt('primary')->question
        ->regex;
}

#######################################################################
#                         External Interface                          #
#######################################################################

sub get_modifiers {
    my $groups = shift;
    my @applicable_modifiers = ();
    return unless @$groups;
    foreach my $modifier (@modifier_specs) {
        my $required_groups = $modifier->{required_groups};
        if ($required_groups->(@{$groups})) {
            push @applicable_modifiers, new_modifier($modifier);
        }
    };
    return @applicable_modifiers;
}

1;
