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
# GetAnswers
#===========================================================


#===========================================================
# Concretize
#===========================================================

our proto Concretize($sf, $command, *%args) is export {*}

multi sub Concretize(Whatever, $command, *%args) {
    # Apply a classifier to the workflow
}

multi sub Concretize(Str $sf,
                     $command,
                     Str :$lang = 'WL',
                     Bool :$avoid-monads = False,
                     :$format is copy = 'hash',
                     :$user-id = ''
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

    my $ans = find-textual-answer($command, @questions2, llm => 'palm', max-tokens => 400, temperature => 0.5):!echo:pairs;

    my $tmpl = get-specs<Templates>{$sf}{$lang};

    my $tmpl2 = $tmpl.values.head.head<Value>;

    #------------------------------------------------------
    # Process template
    #------------------------------------------------------

    if $ans ~~ Positional {

        my %answers = |$ans;

        my $tmplFilledIn = $tmpl2;

        for %questionToParam.kv -> $k, $v {
            $tmplFilledIn .= subst( /  ',' \h* 'TemplateSlot["' $v '"]' \h* ',' \h* /, %answers{$k ~ '?'}):g;
        }

        $tmplFilledIn .= subst(/ ^ 'TemplateObject[{"'/, '');
        $tmplFilledIn .= subst(/ '"},' \h* 'CombinerFunction -> StringJoin' \h* ',' \h* 'InsertionFunction -> TextString]' $ /, '');

        return $tmplFilledIn;
    }

}

