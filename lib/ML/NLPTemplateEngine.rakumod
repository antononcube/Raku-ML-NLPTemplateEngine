use v6.d;

use ML::NLPTemplateEngine::Core;
use ML::NLPTemplateEngine::Ingestion;

unit module ML::NLPTemplateEngine;

#===========================================================
#| Finds parameter values to fill-in the slots of templates using based on the natural language specifications.
our proto concretize(|) is export {*}

multi sub concretize(**@args, *%args) {
    return ML::NLPTemplateEngine::Core::Concretize(|@args, |%args);
}


