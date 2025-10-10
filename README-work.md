# ML::NLPTemplateEngine

This Raku package aims to create (nearly) executable code for various computational workflows.

Package's data and implementation make a Natural Language Processing (NLP)
[Template Engine (TE)](https://en.wikipedia.org/wiki/Template_processor), [Wk1],
that incorporates
[Question Answering Systems (QAS')](https://en.wikipedia.org/wiki/Question_answering), [Wk2],
and Machine Learning (ML) classifiers.

The current version of the NLP-TE of the package heavily relies on Large Language Models (LLMs) for its QAS component.

Future plans involve incorporating other types of QAS implementations.

The Raku package implementation closely follows the Wolfram Language (WL) implementations in
["NLP Template Engine"](https://github.com/antononcube/NLP-Template-Engine), [AAr1, AAv1],
and the WL paclet
["NLPTemplateEngine"](https://resources.wolframcloud.com/PacletRepository/resources/AntonAntonov/NLPTemplateEngine/), [AAp2, AAv2].

An alternative, more comprehensive approach to building workflows code is given in [AAp2].
Another alternative is to use few-shot training of LLMs with examples provided by, say,
the Raku package ["DSL::Examples"](https://raku.land/zef:antononcube/DSL::Examples), [AAp3].

### Problem formulation

We want to have a system (i.e. TE) that:

1. Generates relevant, correct, executable programming code based on natural language specifications of computational
   workflows

2. Can automatically recognize the workflow types

3. Can generate code for different programming languages and related software packages

The points above are given in order of importance; the most important are placed first.

### Reliability of results

One of the main reasons to re-implement the WL NLP-TE, [AAr1, AAp1], into Raku is to have a more robust way
of utilizing LLMs to generate code. That goal is more or less achieved with this package, but
YMMV -- if incomplete or wrong results are obtained run the NLP-TE with different LLM parameter settings
or different LLMs.

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

```raku
use ML::NLPTemplateEngine;

my $qrCommand = q:to/END/;
Compute quantile regression with probabilities 0.4 and 0.6, with interpolation order 2, for the dataset dfTempBoston.
END

concretize($qrCommand);
```

**Remark:** In the code above the template type, "QuantileRegression", was determined using an LLM-based classifier.

### Latent Semantic Analysis (R)

```raku
my $lsaCommand = q:to/END/;
Extract 20 topics from the text corpus aAbstracts using the method NNMF. 
Show statistical thesaurus with the words neural, function, and notebook.
END

concretize($lsaCommand, template => 'LatentSemanticAnalysis', lang => 'R');
```

### Random tabular data generation (Raku)

```raku
my $command = q:to/END/;
Make random table with 6 rows and 4 columns with the names <A1 B2 C3 D4>.
END

concretize($command, template => 'RandomTabularDataset', lang => 'Raku', llm => 'gemini');
```

**Remark:** In the code above it was specified to use Google's Gemini LLM service.

### Recommender workflow (Raku)

```raku
my $command = q:to/END/;
Make a commander over the data set @dsTitanic and compute 8 recommendations for the profile (passengerSex:male, passengerClass:2nd).
END

concretize($command, lang => 'Raku');
```

------

## CLI

The package provides the Command Line Interface (CLI) script `concretize`. Here is usage note:

```shell
concretize --help
```

------

## How it works?

The following flowchart describes how the NLP Template Engine involves a series of steps for processing a computation
specification and executing code to obtain results:

```mermaid
flowchart TD
  spec[/Computation spec/] --> workSpecQ{"Is workflow type<br>specified?"}
  workSpecQ --> |No| guess[[Guess relevant<br>workflow type]]
  workSpecQ -->|Yes| raw[Get raw answers]
  guess -.- classifier[[Classifier:<br>text to workflow type]]
  guess --> raw
  raw --> process[Process raw answers]
  process --> template[Complete<br>computation<br>template]
  template --> execute[/Executable code/]
  execute --> results[/Computation results/]

  llm{{LLM}} -.- find[[find-textual-answer]]
  llm -.- classifier
  subgraph LLM-based functionalities
    classifier
    find
  end

  find --> raw
  raw --> find
  template -.- compData[(Computation<br>templates<br>data)]
  compData -.- process

  classDef highlighted fill:Salmon,stroke:Coral,stroke-width:2px;
  class spec,results highlighted
```

Here's a detailed narration of the process:

1. **Computation Specification**:
    - The process begins with a "Computation spec", which is the initial input defining the requirements or parameters
      for the computation task.

2. **Workflow Type Decision**:
    - A decision node asks if the workflow type is specified.

3. **Guess Workflow Type**:
    - If the workflow type is not specified, the system utilizes a classifier to guess relevant workflow type.

4. **Raw Answers**:
    - Regardless of how the workflow type is determined (directly specified or guessed), the system retrieves "raw
      answers", crucial for further processing.

5. **Processing and Templating**:
    - The raw answers undergo processing ("Process raw answers") to organize or refine the data into a usable format.
    - Processed data is then utilized to "Complete computation template", preparing for executable operations.

6. **Executable Code and Results**:
    - The computation template is transformed into "Executable code", which when run, produces the final "Computation
      results".

7. **LLM-Based Functionalities**:
    - The classifier and the answers finder are LLM-based.

8. **Data and Templates**:
    - Code templates are selected based on the specifics of the initial spec and the processed data.

------

## Bring your own templates

**0.** Load the NLP-Template-Engine package (and others):

```raku
use ML::NLPTemplateEngine;
use Data::Importers;
use Data::Summarizers;
```

**1.** Get the "training" templates data (from CSV file you have created or changed) for a new workflow
(["SendMail"](https://github.com/antononcube/NLP-Template-Engine/blob/main/TemplateData/dsQASParameters-SendMail.csv)):

```raku
my $url = 'https://raw.githubusercontent.com/antononcube/NLP-Template-Engine/main/TemplateData/dsQASParameters-SendMail.csv';
my @dsSendMail = data-import($url, headers => 'auto');

records-summary(@dsSendMail, field-names => <DataType WorkflowType Group Key Value>);
```

**2.** Add the ingested data for the new workflow (from the CSV file) into the NLP-Template-Engine:

```raku
add-template-data(@dsSendMail);
```

**3.** Parse natural language specification with the newly ingested and onboarded workflow ("SendMail"):

```raku
"Send email to joedoe@gmail.com with content RandomReal[343], and the subject this is a random real call."
        ==> concretize(template => "SendMail") 
```

**4.** Experiment with running the generated code!

------

## TODO

- [ ] Templates data
    - [ ] Using JSON instead of CSV format for the templates
        - [ ] Derive suitable data structure
        - [ ] Implement export to JSON
        - [ ] Implement ingestion
    - [ ] Review wrong parameter type specifications
        - A few were found.
    - [ ] New workflows
        - [ ] LLM-workflows
        - [ ] Clustering
        - [ ] Associative rule learning
- [ ] Unit tests
    - What are good ./t unit tests?
    - [ ] Make ingestion ./t unit tests
    - [ ] Make suitable ./xt unit tests
- [ ] Documentation
    - [ ] Comparison with LLM code generation using few-shot examples
    - [ ] Video demonstrating the functionalities

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
[NLPTemplateEngine, WL paclet](https://resources.wolframcloud.com/PacletRepository/resources/AntonAntonov/NLPTemplateEngine/),
(2023),
[Wolfram Language Paclet Repository](https://resources.wolframcloud.com/PacletRepository/).

[AAp2] Anton Antonov,
[DSL::Translators, Raku package](https://github.com/antononcube/Raku-DSL-Translators),
(2020-2025),
[GitHub/antononcube](https://github.com/antononcube).

[AAp3] Anton Antonov,
[DSL::Examples, Raku package](https://github.com/antononcube/Raku-DSL-Examples),
(2024-2025),
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
