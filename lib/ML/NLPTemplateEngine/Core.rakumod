unit module ML::NLPTemplateEngine::Core;

use ML::FindTextualAnswer;
use ML::NLPTemplateEngine::Ingestion;
use Hash::Merge;

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
        RandomTabularDataset => 'Random Tabular Dataset',
        ProgrammingEnvironment => 'Programming Environment';

my %workflowFullNameToSpec = %workflowSpecToFullName.pairs.classify({ $_.value }).map({ $_.key => $_.value>>.key });

#===========================================================
# Concretize
#===========================================================

our proto Concretize($command, *%args) is export {*}

multi sub Concretize($command,
                     :$template is copy where $template.isa(Whatever) || $template.isa(WhateverCode) = Whatever,
                     *%args)
{

    my @lbls = %workflowSpecToFullName.values.unique.grep({ $_ ∉ ['Programming Environment'] });

    my %args2 = { request => 'which of these workflows characterizes it', llm-evaluator => %args<llm-evaluator> //
            %args<e> // %args<finder> // Whatever }, %args;
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

    note (find-textual-answer => $ans.raku) if $echo;

    my $tmpl = get-specs<Templates>{$template}{$lang};

    my $tmpl2 = $tmpl.values.head.head<Value>;

    note (template => $tmpl2) if $echo;

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
                        right-list-bracket => ']', double-quote => '"'),
            r => %(Automatic => 'NULL', True => 'TRUE', False => 'FALSE', left-list-bracket => 'c(',
                   right-list-bracket => ')', double-quote => '"'),
            raku => %(Automatic => 'Whatever', True => 'True', False => 'False', left-list-bracket => '[',
                      right-list-bracket => ']', double-quote => '"'),
            wl => %(Automatic => 'Automatic', True => 'True', False => 'False', left-list-bracket => '{',
                    right-list-bracket => '}', double-quote => '"');

    %syntax = %syntax{$lang.lc} // %syntax<raku>;

    #------------------------------------------------------
    # Process template
    #------------------------------------------------------

    if $ans ~~ Positional:D | Associative:D {

        my %answers = |$ans;

        # Get parameter-to-answer mapping
        my %paramToAnswer = do for %questionToParam.kv -> $k, $param {
            my $ans = %answers{$k ~ '?'};

            if $ans.lc ∈ <n/a none null> {
                $ans = get-specs<Defaults>{$template}{$param} // ('$*' ~ $param);
            }

            $param => $ans
        }

        # Complete the answers with defaults
        %paramToAnswer = merge-hash(get-specs<Defaults>{$template}, %paramToAnswer);

        # Get template
        my $tmplFilledIn = $tmpl2;

        # Loop over param-to-answer
        for %paramToAnswer.kv -> $param, $ans {

            my $ans2 = do given %paramTypePatterns{$param} {
                when $_ ∈ <_?BooleanQ Bool> {
                    given $ans.lc {
                        when $_ ∈ <false n/a no none null> { %syntax<False> }
                        when $_ ∈ <automatic auto whatever> { $ans }
                        default { %syntax<True> }
                    }
                }
                when $_ ∈ <{_?StringQ..} {_String..}> {
                    # Tried massaging the LLM prompt of find-textual-answer in order to get JSON list.
                    # Did not work. Hence, this ad hoc list of strings reconstruction.
                    my $ansMod = $ans.split(/ \h* ',' \h*/).map({ %syntax<double-quote> ~ $_ ~ %syntax<double-quote> })
                            .join(', ');
                    "{ %syntax<left-list-bracket> }{ $ansMod }{ %syntax<right-list-bracket> }"
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

        # Final template adjustments
        $tmplFilledIn .= subst(/ ^ 'TemplateObject[{"'/, '');
        $tmplFilledIn .= subst(
                / '"},' \h* 'CombinerFunction -> StringJoin' \h* ',' \h* 'InsertionFunction -> TextString]' $ /, '');

        return $tmplFilledIn;
    }

}

