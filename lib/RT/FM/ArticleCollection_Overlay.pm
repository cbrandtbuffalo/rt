# BEGIN LICENSE BLOCK
#
#  Copyright (c) 2002-2003 Jesse Vincent <jesse@bestpractical.com>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of version 2 of the GNU General Public License
#  as published by the Free Software Foundation.
#
#  A copy of that license should have arrived with this
#  software, but in any event can be snarfed from www.gnu.org.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
# END LICENSE BLOCK

use strict;

package RT::FM::ArticleCollection;

no warnings qw/redefine/;

=head2 Next

Returns the next article that this user can see.

=cut

sub Next {
    my $self = shift;

    my $Object = $self->SUPER::Next();
    if ( ( defined($Object) ) and ( ref($Object) ) ) {

        if ( $Object->CurrentUserHasRight('ShowArticle') ) {
            return ($Object);
        }

        #If the user doesn't have the right to show this Object
        else {
            return ( $self->Next() );
        }
    }

    #if there never was any queue
    else {
        return (undef);
    }

}

=head2 Limit { FIELD  => undef, OPERATOR => '=', VALUE => 'undef'} 

Limit the result set. See DBIx::SearchBuilder docs
In addition to the "normal" stuff, value can be an array.

=cut

sub Limit {
    my $self = shift;
    my %ARGS = (
        OPERATOR => '=',
        @_
    );

    if ( ref( $ARGS{'VALUE'} ) ) {
        my @values = $ARGS{'VALUE'};
        delete $ARGS{'VALUE'};
        foreach my $v (@values) {
            $self->SUPER::Limit( %ARGS, VALUE => $v );
        }
    }
    else {
        $RT::Logger->debug(
            ref($self) . " Limit called :" . join( " ", %ARGS ) );
        $self->SUPER::Limit(%ARGS);
    }
}

=head2 LimitName  { OPERATOR => 'LIKE', VALUE => undef } 

Find all articles with Name fields which satisfy OPERATOR for VALUE

=cut

sub LimitName {
    my $self = shift;

    my %args = (
        FIELD         => 'Name',
        OPERATOR      => 'LIKE',
        CASESENSITIVE => 0,
        VALUE         => undef,
        @_
    );

    $self->Limit(%args);

}

=head2 LimitSummary  { OPERATOR => 'LIKE', VALUE => undef } 

Find all articles with summary fields which satisfy OPERATOR for VALUE

=cut

sub LimitSummary {
    my $self = shift;

    my %args = (
        FIELD         => 'Summary',
        OPERATOR      => 'LIKE',
        CASESENSITIVE => 0,
        VALUE         => undef,
        @_
    );

    $self->Limit(%args);

}

sub LimitCreated {
    my $self = shift;
    my %args = (
        FIELD    => 'Created',
        OPERATOR => undef,
        VALUE    => undef,
        @_
    );

    $self->Limit(%args);

}

sub LimitCreatedBy {
    my $self = shift;
    my %args = (
        FIELD    => 'CreatedBy',
        OPERATOR => '=',
        VALUE    => undef,
        @_
    );

    $self->Limit(%args);

}

sub LimitUpdated {

    my $self = shift;
    my %args = (
        FIELD    => 'Updated',
        OPERATOR => undef,
        VALUE    => undef,
        @_
    );

    $self->Limit(%args);

}

sub LimitUpdatedBy {
    my $self = shift;
    my %args = (
        FIELD    => 'UpdatedBy',
        OPERATOR => '=',
        VALUE    => undef,
        @_
    );

    $self->Limit(%args);

}

# {{{ LimitToParent ID

=item LimitToParent ID

Limit the returned set of articles to articles which are children
of article ID.
This does not recurse.

=cut

sub LimitToParent {
    my $self   = shift;
    my $parent = shift;
    $self->Limit(
        FIELD    => 'Parent',
        OPERATOR => '=',
        VALUE    => $parent
    );

}

# }}}
# {{{ LimitCustomField

=item LimitCustomField HASH

Limit the result set to articles which have or do not have the custom field 
value listed, using a left join to catch things where no rows match.

HASH needs the following fields: 
   FIELD (A custom field id) or undef for any custom field
   ENTRYAGGREGATOR => (AND, OR)
   OPERATOR ('=', 'LIKE', '!=', 'NOT LIKE')
   VALUE ( a single scalar value or a list of possible values to be concatenated with ENTRYAGGREGATOR)
   

=cut

sub LimitCustomField {
    my $self = shift;
    my %args = (
        FIELD           => undef,
        ENTRYAGGREGATOR => 'OR',
        OPERATOR        => '=',
        QUOTEVALUE      => 1,
        VALUE           => undef,
        @_
    );

    #lets get all those values in an array. regardless of # of entries
    #we'll use this for adding and deleting keywords from this object.
    my @values =
      ref( $args{'VALUE'} ) ? @{ $args{'VALUE'} } : ( $args{'VALUE'} );

    foreach my $value (@values) {
        next unless $value;    #strip out total blank wildcards
        my $ObjectValuesAlias = $self->Join(
            TYPE   => 'left',
            ALIAS1 => 'main',
            FIELD1 => 'id',
            TABLE2 => 'ObjectCustomFieldValues',
            FIELD2 => 'ObjectId'
        );
        $self->Limit( ALIAS=> $ObjectValuesAlias, FIELD => 'ObjectType', VALUE => 'RT::FM::Article');

        if ( $args{'FIELD'} ) {
            $self->Limit(
                ALIAS           => $ObjectValuesAlias,
                FIELD           => 'CustomField',
                VALUE           => $args{'FIELD'},
                ENTRYAGGREGATOR => 'OR'
            );

            $self->SUPER::Limit(
                ALIAS           => $ObjectValuesAlias,
                FIELD           => 'CustomField',
                OPERATOR        => 'IS',
                VALUE           => 'NULL',
                QUOTEVALUE      => 0,
                ENTRYAGGREGATOR => 'OR',
            );
        }

      #If we're trying to find articles where a custom field value doesn't match
      # something, be sure to find  things where it's null

#basically, we do a left join on the value being applicable to the article and then we turn around
# and make sure that it's actually null in practise

        #TODO this should deal with starts with and ends with

        if ( $args{'OPERATOR'} eq '!=' || $args{'OPERATOR'} =~ /^not like$/i ) {
            my $op;
            if ( $args{'OPERATOR'} eq '!=' ) {
                $op = "=";
            }
            elsif ( $args{'OPERATOR'} =~ /^not like$/i ) {
                $op = 'LIKE';
            }

            $self->SUPER::Limit(
                LEFTJOIN        => $ObjectValuesAlias,
                FIELD           => 'Content',
                OPERATOR        => $op,
                VALUE           => $value,
                QUOTEVALUE      => $args{'QUOTEVALUE'},
                ENTRYAGGREGATOR => $args{'ENTRYAGGREGATOR'},
            );
            $self->SUPER::Limit(
                ALIAS           => $ObjectValuesAlias,
                FIELD           => 'Content',
                OPERATOR        => 'IS',
                VALUE           => 'NULL',
                QUOTEVALUE      => 0,
                ENTRYAGGREGATOR => 'OR',
            );
        }
        else {
            $self->SUPER::Limit(
                ALIAS           => $ObjectValuesAlias,
                FIELD           => 'Content',
                OPERATOR        => $args{'OPERATOR'},
                VALUE           => $value,
                QUOTEVALUE      => $args{'QUOTEVALUE'},
                ENTRYAGGREGATOR => $args{'ENTRYAGGREGATOR'},
            );
        }
    }
}

# }}}

# {{{ LimitTopics
sub LimitTopics {
    my $self   = shift;
    my @topics = @_;

    my $topics = $self->NewAlias('FM_ObjectTopics');
    $self->Limit(
        ALIAS           => $topics,
        FIELD           => 'Topic',
        VALUE           => $_,
        ENTRYAGGREGATOR => 'OR'
      )
      for @topics;

    $self->Limit(
        ALIAS => $topics,
        FIELD => 'ObjectType',
        VALUE => 'RT::FM::Article',
    );
    $self->Join(
        ALIAS1 => 'main',
        FIELD1 => 'id',
        ALIAS2 => $topics,
        FIELD2 => 'ObjectId',
    );
}

# }}}

# {{{ LimitRefersTo URI

=head2 LimitRefersTo URI

Limit the result set to only articles which are referred to by the URI passed in.

=cut

sub LimitRefersTo {
    my $self = shift;
    my $uri  = shift;

    my $links = $self->NewAlias('Links');
    $self->Limit(
        ALIAS => $links,
        FIELD => 'Target',
        VALUE => $uri
    );

    $self->Join(
        ALIAS1 => 'main',
        FIELD1 => 'URI',
        ALIAS2 => $links,
        FIELD2 => 'Base'
    );

}

# }}}

# {{{ LimitReferredToBy URI

=head2 LimitReferredToBy URI

Limit the result set to only articles which are referred to by the URI passed in.

=cut

sub LimitReferredToBy {
    my $self = shift;
    my $uri  = shift;

    my $links = $self->NewAlias('Links');
    $self->Limit(
        ALIAS => $links,
        FIELD => 'Base',
        VALUE => $uri
    );

    $self->Join(
        ALIAS1 => 'main',
        FIELD1 => 'URI',
        ALIAS2 => $links,
        FIELD2 => 'Target'
    );

}

# }}}

1;
