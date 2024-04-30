#!/usr/bin/env raku
use v6.d;

use lib <. lib>;

use ML::NLPTemplateEngine;
use ML::NLPTemplateEngine::Core;

use Data::ExampleDatasets;
use Data::Summarizers;
use Data::Importers;

use JSON::Fast;

my $lang = 'WL';
my $llm = 'gemini';
my $model = 'gemini-1.0-pro';

my $url = 'https://raw.githubusercontent.com/antononcube/NLP-Template-Engine/main/TemplateData/dsQASParameters-SendMail.csv';
my @dsSendMail = data-import($url, headers => 'auto');

records-summary(@dsSendMail, field-names => <DataType WorkflowType Group Key Value>);

say add-template-data(@dsSendMail);

say concretize('SendMail',
        "Send email to joedoe@gmail.com with content RandomReal[343], and the subject this is a random real call.",
        :$lang, :$llm, :$model, max-tokens => 300, temperature => 0.3):!echo;
