# ML::NLPTemplateEngine

A Raku package is available that provides an NLP template engine to create various computational workflows.

Package's data and implementation make a Natural Language Processing (NLP)
[Template Engine (TE)](https://en.wikipedia.org/wiki/Template_processor), [Wk1],
that incorporates
[Question Answering Systems (QAS')](https://en.wikipedia.org/wiki/Question_answering), [Wk2],
and Machine Learning (ML) classifiers.

The current version of the NLP-TE of the package heavily relies on Large Language Models (LLMs) for its QAS component.

Future plans involve incorporating other types of QAS implementations.

The Raku package implementation close follows the Wolfram Language (WL) implementations in
["NLP Template Engine"](https://github.com/antononcube/NLP-Template-Engine), [AAr1, AAv1],
and the WL paclet
["NLPTemplateEngine"](https://resources.wolframcloud.com/PacletRepository/resources/AntonAntonov/NLPTemplateEngine/), [AAp2, AAv2].

An alternative, more comprehensive approach to building workflows code is given in [AAp2].

### Problem formulation

We want to have a system (i.e. TE) that:

1. Generates relevant, correct, executable programming code based on natural language specifications of computational
   workflows

2. Can automatically recognize the workflow types

3. Can generate code for different programming languages and related software packages

The points above are given in order of importance; the most important are placed first.

------

## Installation

From Zef ecosystem:

```
zef install ML::NLPTemplateEngine;
```

From GitHub:

```
zef install https://github.com/antononcube/Raku-ML-NLPTemplateEngine.git
```

-----

## Usage examples

### Quantile Regression (WL)

Here the template is automatically determined:

```perl6
use ML::NLPTemplateEngine;

my $qrCommand = q:to/END/;
Compute quantile regression with probabilities 0.4 and 0.6, with interpolation order 2, for the dataset dfTempBoston.
END

concretize($qrCommand);
```

```
# qrObj=
# QRMonUnit[dfTempBoston]⟹
# QRMonEchoDataSummary[]⟹
# QRMonQuantileRegression[N/A, 0.4, 0.6, InterpolationOrder->2]⟹
# QRMonPlot["DateListPlot"-> N/A,PlotTheme->"Detailed"]⟹
# QRMonErrorPlots["RelativeErrors"->N/A,"DateListPlot"-> N/A,PlotTheme->"Detailed"];
```

**Remark:** In the code above the template type, "QuantileRegression", was determined using an LLM-based classifier.

### Latent Semantic Analysis (R)

```perl6
my $lsaCommand = q:to/END/;
Extract 20 topics from the text corpus aAbstracts using the method NNMF. 
Show statistical thesaurus with the words neural, function, and notebook.
END

concretize($lsaCommand, template => 'LatentSemanticAnalysis', lang => 'R');
```

```
# lsaObj <-
# LSAMonUnit(aAbstracts) %>%
# LSAMonMakeDocumentTermMatrix(stemWordsQ = No, stopWords = $*stopWords) %>%
# LSAMonEchoDocumentTermMatrixStatistics(logBase = 10) %>%
# LSAMonApplyTermWeightFunctions(globalWeightFunction = "$*globalWeightFunction", localWeightFunction = "$*localWeightFunction", normalizerFunction = "$*normalizerFunction") %>%
# LSAMonExtractTopics(numberOfTopics = 20, method = "NNMF", maxSteps = $*maxSteps, minNumberOfDocumentsPerTerm = $*minNumberOfDocumentsPerTerm) %>%
# LSAMonEchoTopicsTable(numberOfTerms = 20, wideFormQ = TRUE) %>%
# LSAMonEchoStatisticalThesaurus(words = neural, function, notebook)
```

### Random tabular data generation (Raku)

```perl6
my $command = q:to/END/;
Make random table with 6 rows and 4 columns with the names <A1 B2 C3 D4>.
END

concretize($command, template => 'RandomTabularDataset', lang => 'Raku', llm => 'gemini');
```

```
# random-tabular-dataset(6, 4, "column-names-generator" => Letters and numbers combination, "form" => "Table with 6 rows and 4 columns", "max-number-of-values" => 24, "min-number-of-values" => 4, "row-names" => $*rowKeys)
```

**Remark:** In the code above it was specified to use Google's Gemini LLM service.

------

## Bring your own templates

**0.** Load the NLP-Template-Engine package (and others):

```perl6
use ML::NLPTemplateEngine;
use Data::Importers;
use Data::Summarizers;
```

```
# (Any)
```

**1.** Get the "training" templates data (from CSV file you have created or changed) for a new workflow
(["SendMail"](https://github.com/antononcube/NLP-Template-Engine/blob/main/TemplateData/dsQASParameters-SendMail.csv)):

```perl6
my $url = 'https://raw.githubusercontent.com/antononcube/NLP-Template-Engine/main/TemplateData/dsQASParameters-SendMail.csv';
my @dsSendMail = data-import($url, headers => 'auto');

records-summary(@dsSendMail, field-names => <DataType WorkflowType Group Key Value>);
```

```
# +-----------------+----------------+-----------------------------+----------------------------+----------------------------------------------------------------------------------+
# | DataType        | WorkflowType   | Group                       | Key                        | Value                                                                            |
# +-----------------+----------------+-----------------------------+----------------------------+----------------------------------------------------------------------------------+
# | Questions => 48 | SendMail => 60 | All                   => 9  | ContextWordsToRemove => 12 | 0.35                                                                       => 9  |
# | Defaults  => 7  |                | Which files to attach => 4  | Threshold            => 12 | {_String..}                                                                => 8  |
# | Templates => 3  |                | What it the content   => 4  | TypePattern          => 12 | {"to", "email", "mail", "send", "it", "recipient", "addressee", "address"} => 4  |
# | Shortcuts => 2  |                | Who to send it to     => 4  | Parameter            => 12 | _String                                                                    => 4  |
# |                 |                | Who is it from        => 4  | Template             => 3  | None                                                                       => 4  |
# |                 |                | Who the email is from => 4  | body                 => 1  | to                                                                         => 4  |
# |                 |                | Which api key         => 4  | bodyHTML             => 1  | body                                                                       => 3  |
# |                 |                | (Other)               => 27 | (Other)              => 7  | (Other)                                                                    => 24 |
# +-----------------+----------------+-----------------------------+----------------------------+----------------------------------------------------------------------------------+
```

**2.** Add the ingested data for the new workflow (from the CSV file) into the NLP-Template-Engine:

```perl6
add-template-data(@dsSendMail);
```

```
# (Templates ParameterQuestions Defaults Questions Shortcuts)
```

**3.** Parse natural language specification with the newly ingested and onboarded workflow ("SendMail"):

```perl6
"Send email to joedoe@gmail.com with content RandomReal[343], and the subject this is a random real call."
        ==> concretize(template => "SendMail") 
```

```
# SendMail[<|"To"->joedoe@gmail.com,"Subject"->"this is a random real call.","Body"->RandomReal[343],"AttachedFiles"->`attachedFiles`|>]
```

**4.** Experiment with running the generated code!

------

## References

### Articles

[Wk1] Wikipedia entry, [Template processor](https://en.wikipedia.org/wiki/Template_processor).

[Wk2] Wikipedia entry, [Question answering](https://en.wikipedia.org/wiki/Question_answering).

### Functions, packages, repositories

[AAr1] Anton Antonov,
["NLP Template Engine"](https://github.com/antononcube/NLP-Template-Engine),
(2021-2022),
[GitHub/antononcube](https://github.com/antononcube).

[AAp1] Anton Antonov,
[NLPTemplateEngine WL paclet](https://resources.wolframcloud.com/PacletRepository/resources/AntonAntonov/NLPTemplateEngine/),
(2023),
[Wolfram Language Paclet Repository](https://resources.wolframcloud.com/PacletRepository/).

[AAp2] Anton Antonov,
[DSL::Translators Raku package](https://github.com/antononcube/Raku-DSL-Translators),
(2020-2024),
[GitHub/antononcube](https://github.com/antononcube).

[WRI1] Wolfram Research,
[FindTextualAnswer]( https://reference.wolfram.com/language/ref/FindTextualAnswer.html),
(2018),
[Wolfram Language function](https://reference.wolfram.com), (updated 2020).

### Videos

[AAv1] Anton Antonov,
["NLP Template Engine, Part 1"](https://youtu.be/a6PvmZnvF9I),
(2021),
[YouTube/@AAA4Prediction](https://www.youtube.com/@AAA4Prediction).

[AAv2] Anton Antonov,
["Natural Language Processing Template Engine"](https://www.youtube.com/watch?v=IrIW9dB5sRM) presentation given at
WTC-2022,
(2023),
[YouTube/@Wolfram](https://www.youtube.com/@Wolfram).
