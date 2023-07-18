use v6.d;

use ML::FindTextualAnswer;
use ML::NLPTemplateEngine::Ingestion;

unit module ML::NLPTemplateEngine::Core;

#===========================================================
# Specs
#===========================================================

our %qasSpecs;

sub get-specs(Str $type = 'standard') is export {

    if %qasSpecs { return %qasSpecs; }

    %qasSpecs = ConvertCSVData(%?RESOURCES<dfQASParameters.csv>.Str);

    return %qasSpecs;
}

#===========================================================
# GetAnswers
#===========================================================


#===========================================================
# Workflows remapping
#===========================================================

my %workflowSpecToFullName =
        Classification => 'Classification',
        ClCon => 'Classification',
        LatentSemanticAnalysis => 'Latent Semantic Analysis',
        #LSAMon => 'Latent Semantic Analysis',
        QuantileRegression => 'Quantile Regression',
        Recommendations => 'Recommendations',
        #SMRMon => 'Recommendations',
        QRMon => 'Quantile Regression',
        RandomTabularDataset => 'RandomTabularDataset',
        ProgrammingEnvironment => 'ProgrammingEnvironment';

my %workflowFullNameToSpec = %workflowSpecToFullName.pairs.classify({ $_.value }).map({ $_.key => $_.value>>.key });

#===========================================================
# Concretize
#===========================================================

our proto Concretize($sf, $command, *%args) is export {*}

multi sub Concretize(Whatever, $command, *%args) {

    my @lbls = %workflowSpecToFullName.values.unique;

    my %args2 = {request => 'which of these workflows characterizes it'} , %args;
    my $sf = llm-classify($command, @lbls, |%args2);

    if %args<echo> // False {
        note "Workflow classification result: $sf";
    }

    if %workflowFullNameToSpec{$sf}:exists {

        # Pick workflow
        my $sf2 = %workflowFullNameToSpec{$sf};

        if $sf2 ~~ Positional {
            $sf2 = $sf2.grep({ $_ ∈ <LSAMon ClCon SMRMon QRMon> });
            if !$sf2.elems { $sf2 = %workflowFullNameToSpec{$sf} }
            $sf2 = $sf2.head;
        }

        # Delegate
        return Concretize($sf2, $command, |%args);

    } else {
        die 'Cannot determine the wokflow type of the given command.';
    }
}

multi sub Concretize(Str $sf,
                     $command,
                     Str :$lang = 'WL',
                     Bool :$avoid-monads = False,
                     :$format is copy = 'hash',
                     :$user-id = '',
                     *%args
                     ) {


    #------------------------------------------------------
    if $format.isa(Whatever) { $format = 'hash' }
    die "The argument \$format is expected to be one of 'hash', 'code', or Whatever"
    unless $format ~~ Str && $format ∈ <hash code>;

    #------------------------------------------------------
    die "There is no template for the language $lang."
    unless get-specs<Templates>{$sf}{$lang}:exists;

    #------------------------------------------------------
    # Get questions
    #------------------------------------------------------

    my %qas2 = get-specs()<ParameterQuestions>{$sf};

    my %paramToQuestion = %qas2.map({ $_.key => $_.value.keys.pick });

    my %questionToParam = %paramToQuestion.invert;

    my @questions2 = %questionToParam.keys;

    @questions2 = @questions2 »~» '?';

    #------------------------------------------------------
    # Find answers
    #------------------------------------------------------

    my %args2 = %args.grep({ $_.key ∉ <pairs p> });
    my $ans = find-textual-answer($command, @questions2, |%args2):pairs;

    my $tmpl = get-specs<Templates>{$sf}{$lang};

    my $tmpl2 = $tmpl.values.head.head<Value>;

    #------------------------------------------------------
    # Remove residual words
    #------------------------------------------------------

    #------------------------------------------------------
    # Process template
    #------------------------------------------------------

    if $ans ~~ Positional {

        my %answers = |$ans;

        my $tmplFilledIn = $tmpl2;

        for %questionToParam.kv -> $k, $v {
            $tmplFilledIn .= subst( /  ',' \h* 'TemplateSlot["' $v '"]' \h* ',' \h* /, %answers{$k ~ '?'}):g;
            $tmplFilledIn .= subst( / '`' $v '`' /, %answers{$k ~ '?'}):g;
            $tmplFilledIn .= subst( / '$*' $v /, %answers{$k ~ '?'}):g;
        }

        $tmplFilledIn .= subst(/ ^ 'TemplateObject[{"'/, '');
        $tmplFilledIn .= subst(/ '"},' \h* 'CombinerFunction -> StringJoin' \h* ',' \h* 'InsertionFunction -> TextString]' $ /, '');

        return $tmplFilledIn;
    }

}

