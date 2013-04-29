package Iota::IndicatorData;

use Moose;
use Iota::IndicatorFormula;
has schema => (
    is         => 'ro',
    isa        => 'Any',
    required   => 1
);

sub upsert {
    my ($self, %params) = @_;

    my $ind_rs = $self->schema->resultset('Indicator');

    # procura pelos indicadores enviados
    $ind_rs = $ind_rs->search( { id => $params{indicators} })
        if exists $params{indicators};

    my @indicators     = $ind_rs->all;
    my @indicators_ids = map { $_->id } @indicators;

    # procura por todas as variaveis que esses indicadores podem utilizar
    my @used_variables = $self->schema->resultset('IndicatorVariable')->search({
        indicator_id => \@indicators_ids
    })->all;

    my $variable_ids;
    my $indicator_variables;
    foreach my $var (@used_variables){
        $variable_ids->{$var->variable_id} = 1;
        push @{$indicator_variables->{$var->indicator_id}}, $var->variable_id;
    }

    # procura pelos valores salvos
    my $values_rs = $self->schema->resultset('VariableValue');
    $values_rs = $values_rs->search({
        valid_from => $params{dates}
    }) if exists $params{dates};

    $values_rs = $values_rs->search({
        (exists $params{user_id} ? ('me.user_id' => $params{user_id}) : ()),
        'me.variable_id' => [(keys %$variable_ids)]
    });

    my $period_values = $self->_get_values_periods($values_rs);

    my $results = $self->_get_indicator_values(
        indicators => \@indicators,
        values     => $period_values,

        indicator_variables => $indicator_variables,

    );



}

# monta na RAM a estrutura:
# $period_values = $user_id => { $valid_from => { $variable_id => [ $value, $source ] } }
# assim fica facil saber se em determinado periodo
# existem dados para todas as variaveis

sub _get_values_periods {
    my ($self, $rs) = @_;

    $rs = $rs->as_hashref;

    my $out = {};

    while (my $row = $rs->next){

        next if !defined $row->{value} || $row->{value} eq '';

        $out->{$row->{user_id}}{$row->{valid_from}}{$row->{variable_id}} = [
            $row->{value}, $row->{source},
        ];
    }

    return $out;
}



sub _get_indicator_values {
    my ($self, %params) = @_;

    my $out = {};
    foreach my $indicator (@{$params{indicators}}){

        my @variables = exists $params{indicator_variables}{$indicator->id}
            ? sort {$a <=> $b} @{$params{indicator_variables}{$indicator->id}}
            : ();

        foreach my $user_id ( keys %{$params{values}} ){
            foreach my $date ( keys %{$params{values}{$user_id}} ){
                my $data = $params{values}{$user_id}{$date};

                my $filled = 0;
                do { $filled++ if exists $data->{$_} } for @variables;


                next unless $filled == @variables;


                my $formula = Iota::IndicatorFormula->new(
                    formula => $indicator->formula,
                    schema  => $self->schema
                );

                my $valor = $formula->evaluate(
                    map { $_ => $data->{$_}[0] } @variables
                );

                my %sources;
                for my $var (@variables){
                    my $str = $data->{$var}[1];
                    next unless $str;
                    $sources{$str}++;
                }

                $out->{$user_id}{$indicator->id}{$date} = [
                    $valor,
                    [ keys %sources ]
                ];

            }
        }
    }
    return $out;
}

sub indicators_from_variables {
    my ($self, %params) = @_;

    die "param variables missing" unless exists $params{variables};

    my @indicators = $self->schema->resultset('IndicatorVariable')->search({
        variable_id => $params{variables}
    },
    {
        columns  => ['indicator_id'],
        group_by => ['indicator_id'],
    })->all;

    my @ids = map { $_->indicator_id } @indicators;
    return wantarray ? @ids : \@ids;
}



1;
