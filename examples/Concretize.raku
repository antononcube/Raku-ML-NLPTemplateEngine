#!/usr/bin/env raku
use v6.d;

use lib '.';
use lib './lib';

use ML::NLPTemplateEngine;

my @commands = [
    'Make a classifier with the method RandomForest over the data dfTitanic; show precision and accuracy; plot True Positive Rate vs Positive Predictive Value.',
    'Make a recommender over the data frame dfOrders. Give the top 5 recommendations for the profile year:2022, type:Clothing, and status:Unpaid',
    'Create an LSA object over the text colletion aAbstracts; extract 40 topics; show statistical thesaurus for "notebook", "equation", "changes", and "prediction"',
    'Compute quantile regression for dfTS with interpolation order 3 and knots 12 for the probabilities 0.2, 0.4, and 0.9.'
];

# This uses workflow classification
for @commands -> $cmd {
    say $cmd;
    say concretize(Whatever, $cmd, llm => 'palm', max-tokens => 300, temperature => 0.3):!echo;
    say '-' x 60;
}

# This uses direct specification of the workflow type
#say concretize('ClCon', $command, llm => 'palm');
