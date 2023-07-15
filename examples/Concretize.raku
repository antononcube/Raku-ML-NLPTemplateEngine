#!/usr/bin/env raku
use v6.d;

use lib '.';
use lib './lib';

use ML::NLPTemplateEngine;

my $command = "Make classifier with the method Random Forest over the data dfTitanic. Show Precision and Recall. Split the data with ratio 0.75; plot ROC functions PPV vs TPR.";

say concretize('ClCon', $command);