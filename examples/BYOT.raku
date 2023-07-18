#!/usr/bin/env raku
use v6.d;

use lib '.';
use lib './lib';

use ML::NLPTemplateEngine;
use ML::NLPTemplateEngine::Core;

use Data::ExampleDatasets;
use Data::Summarizers;

use Text::CSV;
use JSON::Fast;

my $lang = 'WL';
my $llm = 'openai';
my $model = 'text-davinci-003';


#my $url = 'https://raw.githubusercontent.com/antononcube/NLP-Template-Engine/main/TemplateData/dsQASParameters-SendMail.csv';
#my @dsSendMail = example-dataset($url);

my $fileName = $*CWD ~ '/../NLP-Template-Engine/TemplateData/dsQASParameters-SendMail.csv';
my @dsSendMail = csv(in => $fileName, headers => 'auto');

records-summary(@dsSendMail);

say add-template-data(@dsSendMail);

say concretize('SendMail',
        "Send email to joedoe@gmail.com with content RandomReal[343], and the subject this is a random real call.",
        :$lang, :$llm, :$model, max-tokens => 300, temperature => 0.3):echo;
