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

    %qasSpecs = ConvertCSVData(%?RESOURCES<dfQASParameters.csv>.open);

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

our proto Concretize($command, *%args) is export {*}

multi sub Concretize($command,
                     :$template is copy where $template.isa(Whatever) || $template.isa(WhateverCode) = Whatever,
                     *%args)
{

    my @lbls = %workflowSpecToFullName.values.unique;

    my %args2 = { request => 'which of these workflows characterizes it' }, %args;
    $template = llm-classify($command, @lbls, |%args2);

    if %args<echo> // False {
        note "Workflow classification result: $template";
    }

    if %workflowFullNameToSpec{$template}:exists {

        # Pick workflow
        my $template2 = %workflowFullNameToSpec{$template};

        if $template2 ~~ Positional:D {
            $template2 = $template2.grep({ $_ ∈ <LSAMon ClCon SMRMon QRMon> });
            if !$template2.elems { $template2 = %workflowFullNameToSpec{$template} }
            $template2 = $template2.head;
        }

        # Delegate
        return Concretize($command, template => $template2, |%args);

    } else {
        die 'Cannot determine the workflow type of the given command.';
    }
}

multi sub Concretize($command,
                     Str:D :$template!,
                     Str:D :$lang = 'WL',
                     Bool:D :$avoid-monads = False,
                     :$format is copy = 'hash',
                     :$user-id = '',
                     *%args
                     ) {

    #------------------------------------------------------
    my Bool $echo = %args<echo> // False;

    #------------------------------------------------------
    if $format.isa(Whatever) { $format = 'hash' }
    die "The argument \$format is expected to be one of 'hash', 'code', or Whatever"
    unless $format ~~ Str && $format ∈ <hash code>;

    #------------------------------------------------------
    die "There is no template $template for the language $lang."
    unless get-specs<Templates>{$template}{$lang}:exists;

    #------------------------------------------------------
    # Get questions
    #------------------------------------------------------

    my %qas2 = get-specs()<ParameterQuestions>{$template};

    my %paramToQuestion = %qas2.map({ $_.key => $_.value.keys.pick });

    my %questionToParam = %paramToQuestion.invert;

    note (:%questionToParam) if $echo;

    my %paramTypePatterns = get-specs()<ParameterTypePatterns>{$template};

    note (:%paramTypePatterns) if $echo;

    my @questions2 = %questionToParam.keys;

    @questions2 = @questions2 »~» '?';

    #------------------------------------------------------
    # Find answers
    #------------------------------------------------------

    my %args2 = %args.grep({ $_.key ∉ <pairs p> });
    my $ans = find-textual-answer($command, @questions2, |%args2):pairs;

    note (:$ans) if $echo;

    my $tmpl = get-specs<Templates>{$template}{$lang};

    my $tmpl2 = $tmpl.values.head.head<Value>;

    note (:$tmpl2) if $echo;

    #------------------------------------------------------
    # Remove residual words
    #------------------------------------------------------
    # Not needed because LLNs produce "precise" answers most of the time.

    #------------------------------------------------------
    # Localization
    #------------------------------------------------------
    # Different programming languages have different syntax for lists, strings, etc.
    # The alternative is to generate JSON answers with QAS and then localize those JSONs.
    # But that still requires per-language translation step.

    my %syntax =
            python => %(Automatic => 'None', True => 'True', False => 'False', left-list-bracket => '[',
                        right-list-bracket => ']'),
            r => %(Automatic => 'NULL', True => 'TRUE', False => 'FALSE', left-list-bracket => 'c(',
                   right-list-bracket => ')'),
            raku => %(Automatic => 'Whatever', True => 'True', False => 'False', left-list-bracket => '[',
                      right-list-bracket => ']'),
            wl => %(Automatic => 'Automatic', True => 'True', False => 'False', left-list-bracket => '{',
                    right-list-bracket => '}');

    %syntax = %syntax{$lang.lc} // %syntax<raku>;

    note (syntax => %syntax.raku);

    #------------------------------------------------------
    # Process template
    #------------------------------------------------------

    if $ans ~~ Positional:D | Associative:D {

        my %answers = |$ans;

        my $tmplFilledIn = $tmpl2;

        for %questionToParam.kv -> $k, $param {
            my $ans = %answers{$k ~ '?'};

            my $ans2 = do given %paramTypePatterns{$param} {
                when $_ ∈ <_?BooleanQ Bool> {
                    $ans.lc ∈ <false n/a no none null> ?? %syntax<False> !! %syntax<True>
                }
                when $_ ∈ <{_?StringQ..} {_String..}> {
                    "{ %syntax<left-list-bracket> }{ $ans }{ %syntax<right-list-bracket> }"
                }
                when $_ ∈ <{_?NumericQ..} {_?NumberQ..} {_Integer..} {_?IntegerQ..}> {
                    "{ %syntax<left-list-bracket> }{ $ans }{ %syntax<right-list-bracket> }"
                }
                default {
                    $ans
                }
            }

            $tmplFilledIn .= subst(/  ',' \h* 'TemplateSlot["' $param '"]' \h* ',' \h* /, $ans2):g;
            $tmplFilledIn .= subst(/ '`' $param '`' /, $ans2):g;
            $tmplFilledIn .= subst(/ '$*' $param /, $ans2):g;
        }

        $tmplFilledIn .= subst(/ ^ 'TemplateObject[{"'/, '');
        $tmplFilledIn .= subst(
                / '"},' \h* 'CombinerFunction -> StringJoin' \h* ',' \h* 'InsertionFunction -> TextString]' $ /, '');

        return $tmplFilledIn;
    }

}

