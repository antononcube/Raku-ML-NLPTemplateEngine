use v6.d;

use Data::Reshapers;
use Data::TypeSystem;
use Text::CSV;

unit module ML::NLPTemplateEngine::Ingestion;

#===========================================================
# Utilities
#===========================================================

sub to-number-maybe(Str $x) {
    my $res = +$x;
    $res.defined ?? $res !! $x
}

#----------------------------------------------------------
multi normalize-quotes(@x) {
    @x.map({ normalize-quotes($_) }).List;
}
multi normalize-quotes(Str $x) {
    if $x ~~ / ^ \" (.+) \" $/ {
        return $0.Str;
    }
    return $x;
}

#----------------------------------------------------------
multi sub from-wl-spec-maybe($x where * !~~ Str) {
    $x
}

multi sub from-wl-spec-maybe(Str $x) {
    my regex wl-spec {
        ^ \{  $<words>=([\" \S+ \"]+ % [\h* ',' \h*]) \} $
    };
    if $x ~~ &wl-spec {
        return $x.substr(1, *- 1).split(/ \h* ',' \h*/, :skip-empty).&normalize-quotes.List;
    }
    return $x;
}

#----------------------------------------------------------
multi sub to-nested-pairs(@x) {
    reduce({ Pair.new($^b, $^a) }, |@x.reverse)
}

#----------------------------------------------------------
multi sub normalize-template(Str $tmpl) {

}

#===========================================================
# ConvertCSVDataForType
#===========================================================

our proto ConvertCSVDataForType(|) is export {*}

multi sub ConvertCSVDataForType(@dsTESpecs, Str $dataType where *eq "ParameterQuestions") {

    my @dsQuery = @dsTESpecs.grep({ $_<DataType> eq $dataType });

    @dsQuery = @dsTESpecs.grep({ $_<Key> eq 'Parameter' });

    my %res = Hash.new.classify-list({
        [
            $_<DataType>,
            $_<WorkflowType>,
            $_<Value>,
            $_<Group>
        ]
    }, @dsQuery);

    return %res;
}

multi sub ConvertCSVDataForType(@dsTESpecs, Str $dataType where *eq "Questions") {

    my @dsQuery = @dsTESpecs.grep({ $_<DataType> eq $dataType });

    my %res = Hash.new.classify-list({
        [
            $_<DataType>,
            $_<WorkflowType>,
            $_<Group>,
            $_<Key>,
            $_<Value>
        ]
    }, @dsQuery);

    return %res;
}

multi sub ConvertCSVDataForType(@dsTESpecs, Str $dataType where *eq "Templates") {

    my @dsQuery = @dsTESpecs.grep({ $_<DataType> eq $dataType });

    # We drop the "Key" column that has to have "Template" value,
    # since that column was added to fit the global long-format CSV.
    my %res = Hash.new.classify-list({
        [
            $_<DataType>,
            $_<WorkflowType>,
            $_<Group>,
            $_<Value>
        ]
    }, @dsQuery);

    return %res;
}

multi sub ConvertCSVDataForType(@dsTESpecs, Str $dataType where *eq "Defaults") {

    my @dsQuery = @dsTESpecs.grep({ $_<DataType> eq $dataType });

    # We drop the "Group" column that has to have "All" value,
    # since that column was added to fit the global long-format CSV.
    # Meaning, currently the defaults depend only from the workflow type,
    # not the workflow type and the target language.

    my %res = Hash.new.classify-list({
        [
            $_<DataType>,
            $_<WorkflowType>,
            $_<Key>,
            $_<Value>
        ]
    }, @dsQuery);

    return %res;
}

multi sub ConvertCSVDataForType(@dsTESpecs, Str $dataType where *eq "Shortcuts") {

    my @dsQuery = @dsTESpecs.grep({ $_<DataType> eq $dataType });

    # We only need "Key" and "Value" for the shortcuts.
    my %res = Hash.new.classify-list({
        [
            $_<DataType>,
            $_<WorkflowType>,
            $_<Group>
        ]
    }, @dsQuery);

    return %res;
}

#===========================================================
# ConvertCSVData
#===========================================================

our proto ConvertCSVData(|) is export {*}

multi sub ConvertCSVData($fileName where *.IO.f) {
    my @dsTESpecs = csv(in => $fileName, headers => 'auto');
    return ConvertCSVData(@dsTESpecs);
}

multi sub ConvertCSVData(@dsTESpecs) {

    # Verify is reshape-able
    my @expectedColumnNames = <DataType WorkflowType Group Key Value>;

    die "The first argument is expected to be a Positional of Maps. " ~
            "Maps are expecteted to have thwith keys { @expectedColumnNames.join(', ') } .)"
    unless is-reshapable(@dsTESpecs, iterable-type => Positional, record-type => Map);

    # Verify column names
    die "The dataset is expected to have the columns { @expectedColumnNames.join(', ') } ."
    unless @dsTESpecs.head.keys.all ∈ @expectedColumnNames;

    # Convert number strings of <Value> into numbers
    my @dsTESpecsLocal = @dsTESpecs.map({
        my $x = $_.clone;
        $x<Value> = to-number-maybe($x<Value>);
        $x
    });

    # Convert WL-list strings of <Value> into lists
    @dsTESpecsLocal = @dsTESpecsLocal.map({
        $_<Value> = from-wl-spec-maybe($_<Value>);
        $_
    });

    # We could have "just" call classify-list,
    # but all nested keys are needed for all types of data.

    # For each data type process the records
    my %res = do for <ParameterQuestions Questions Templates Defaults Shortcuts> -> $dt {
        $dt => ConvertCSVDataForType(@dsTESpecsLocal, $dt).values.head
    }

    return %res;
}