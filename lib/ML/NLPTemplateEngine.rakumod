use v6.d;

use ML::NLPTemplateEngine::Core;
use ML::NLPTemplateEngine::Ingestion;

use Hash::Merge;

unit module ML::NLPTemplateEngine;

#===========================================================
#| Finds parameter values to fill-in the slots of templates using based on the natural language specifications.
our proto concretize(|) is export {*}

multi sub concretize(**@args, *%args) {
    return ML::NLPTemplateEngine::Core::Concretize(|@args, |%args);
}

#===========================================================
#| Add NLP Template Engine data.
our proto add-template-data(|) is export {*}

multi sub add-template-data(@dsQAS) {

    my %newQASSpecs;
    try {
        %newQASSpecs = ConvertCSVData(@dsQAS);
    }

    if $! {
        return "Cannot ingest data.";
    }

    get-specs();

    my @dataTypes = %ML::NLPTemplateEngine::Core::qasSpecs.keys;

    die "The data types of the given data should contain {@dataTypes.keys}."
    unless (@dataTypes (&) %newQASSpecs.keys).elems == @dataTypes.elems;

    for @dataTypes -> $dt {
        %ML::NLPTemplateEngine::Core::qasSpecs{$dt} = merge-hash(%ML::NLPTemplateEngine::Core::qasSpecs{$dt}, %newQASSpecs{$dt});
    }

    return %newQASSpecs.keys;
}