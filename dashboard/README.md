# DeepDive Dashboard

Mindbender provides an interactive dashboard for understanding the state of a DeepDive app.
The dashboard presents a set of *reports* showing aggregate statistics and sampled data products collected from a run of a DeepDive app.
Many common reports built into Mindbender can be easily customized or excluded, and user-defined reports that show app-specific metrics can be produced without much hassle.

This document describes how Mindtagger takes snapshots of the target DeepDive app to produce a set of reports, how a template for each of those reports should look like, how such templates are used to produce the actual reports, and how they are merged into a single snapshot-level report that appears in the dashboard.


## DeepDive Snapshots

After each run of a DeepDive app, `mindbender snapshot` command can be used to produce a *snapshot* under `snapshot/` of the target app with a unique name beginning with a timestamp, e.g., `snapshot/20150206-1/`.

* **Reports**.
  Each snapshot will contain a set of reports that summarize various aspects about the data products of the DeepDive run or the code that produced them.
    * The set of reports to be produced are controlled by a *dashboard configuration* (described in the next section).
    * `reports/` directory contains all the individually produced reports.
    * `README.md` merges those of the individual reports.
    * `reports.json` aggregates all the important values reported by individual reports in a machine-friendlier JSON format.

* **Files**.
  Alongside the reports, copies of important DeepDive artifacts, such as the `application.conf` and extractor code are automatically preserved for future reference under the `files/` directory.
    * The list of files to keep can be enumerated in `snapshot-files` next to the `snapshot/` directory.





## Dashboard Configuration

The list of reports each new snapshot produces should be configured in a *dashboard configuration*.

* A dashboard configuration is a plain text file named `reports.conf` that resides at the root of the target DeepDive app.
* Any text after a `#` character is ignored, so comments can be written there.
* Each of its line begins with either:
    * `section`, followed by a section title, or
    * `report`, followed by a name referring to a *report template* (described in the next section), and zero or more named parameters separated by white space.
* Each time a new snapshot is created, a copy of this dashboard configuration will be retained in the snapshot.

Here's an example dashboard configuration that produces four reports.
```bash
### dashboard configuration

# show statistics about the corpus stored in table "sentences"
report corpus   table=sentences column_document=doc_id column_sentence=sent_id

section "Variables"
report variable/inference    variable=has_spouse.is_correct
report variable/supervision  variable=has_spouse.is_correct top_positive=10 top_negative=10
report variable/feature      variable=has_spouse.is_correct
report variable/candidate    variable=has_spouse.is_correct
```




## Report Template

Each report in a snapshot is produced by a *report template*.

* **Structure**.
  A report template is a carefully structured directory on the file system.
    * It resides under either:
        * `report-templates/` of the target DeepDive app (app-specific), or
        * `dashboard/report-templates/` of Mindbender's source tree (built-in).
    * It is referred from the dashboard configuration with the path name relative to `report-templates/`.
    * It must contain one or more of the following:
        * An executable file named `report.sh`.
        * An executable document `README.md.in`.
        * One or more *nested report templates* (described later).
    * It may contain as many extra files as it needs.
        * All files in the template will be cloned to the report instance.
        * Any file named `*.in` will be considered as executable documents and automatically compiled at production time.
* **Parameters**.
  It takes zero or more named parameters (i.e., `name=value` pairs).
    * The parameters should be declared in the `report.params` file.
    * Each `report` line in the dashboard configuration provides value bindings for these parameters.
    * This allows a template to be instantiated with different sets of parameters to produce multiple reports.
    * The `report.params` file must be formatted in the following way:
        * Each line declares a parameter,
            * whose name may contain only alphanumeric letters and underscore (`_`) and must begin with an alphabet or underscore.
        * A required parameter is declared by a line beginning with `required`, followed by
            * the parameter name, and
            * a description surrounded by quotes.
        * An optional parameter is declared by a line beginning with `optional`, followed by
            * the parameter name,
            * the default value surrounded by quotes, and
            * a description surrounded by quotes.
* **Executables**.
  A report template must contain at least one executable that produces its contents.

    * A `report.sh` shell script can invoke as many other programs as it needs to produce various output files in the report as well as the `README.md` and `report.json`.
        * Several utilities are provided to simplify the common tasks from writing valid JSON to querying data in the underlying database of the DeepDive app.

    * An executable document, named `*.in`, is a text file mixed with shell scripts.
        * Shell script fragments must be surrounded by `<$` and `$>`, e.g.,
            
            ```
            There are <$ run-sql "SELECT COUNT(DISTINCT doc_id) FROM sentences" $> documents in the corpus.
            ```

        * After executing every mixed in shell script in the order they appear, their output will be interpolated with the normal text, and written to a file named without the trailing `.in`, e.g., `README.md.in` will produce a `README.md` after execution.

        * Keeping the reporting logic in executable documents may be simpler than `report.sh` if it mainly computes values to be presented in between a chunk of text, e.g., as for `README.md`.

        * It can be viewed as an inverted shell script, where normal text is written to the output in between running the fragments of shell scripts.


### How Each Report Is Produced

Suppose a line in the dashboard configuration refers to report template `variable/inference` with a named parameter `variable=has_spouse.is_correct`.
Following steps are taken to produce the report.

1. **Instantiation**.
   A *report instance* (or simply *report*) directory is created under `reports/` of the snapshot, e.g., `reports/variable/inference/`.
    * If the same report template is instantiated more than once (most likely with different parameters), the path of the report will be suffixed with a unique serial number, to isolate each report instance from others, e.g., `reports/variable/inference-2/`, `reports/variable/inference-3/`, etc.
    * All files in the template directory for `variable/inference` are cloned into the report instance, preserving the structure within the template.
2. **Parameters**.
   All parameters given by the dashboard configuration are checked against the `report.params` specification
    * If there are `report.params` in the parent directories of the report template, parameters declared in them will also be checked.
      For example, `variable/report.params` as well as `variable/inference/report.params` will be used.
    * Finally, all parameter values are recorded in `report.params.json` in JSON format as well as `.report.params.sh` in a shell script.
3. **Execution**.
   All `report.sh` scripts and executable documents (`*.in`) in the report are executed under a controlled environment:
    * All named parameters for the report are declared as environment variables.
    * Current working directory is set to the report directory.
    This localizes file accesses with the scripts and executable documents, and therefore simplifies reading files in the template as well as generating new ones without having to refer to any global path or variables.


### What Each Report Contains After Production

* `README.md` -- a human-readable content of the report in Markdown syntax is expected to be produced.
* `report.json` -- a machine-readable content of the report in JSON format may be produced as well to easily keep track of important values.
* `report.params.json` -- a machine-readable file that records all parameters used for producing the report in JSON format.
    * `.report.params.sh` -- all parameter bindings stored in a shell script, so it can be easily loaded.
    * `.report.params.*` -- other by-products of checking parameters.
* `.report.id` -- a unique identifier (within a snapshot) for the report is generated and stored in this file.
* `*` -- rest of the files are either cloned from the report template, or generated by an executable in the report.


### Extending Report Templates

Report templates are carefully designed to be easily extensible.
Because it is often necessary to augment part of an existing report with app-specific metrics or sample data, the *nested report template* design tries to enable this with minimal user effort, avoiding repetition of existing report templates as much as possible.

* **Nested Report Templates**.
  A report template may be nested under another template.
  When instantiating the parent template from the dashboard configuration,
    * All nested ones will be instantiated with the same set of parameters.
      All `report.params` specifications found along the path to each nested one will be used to check and supply default values for the parameters.
    * App-specific as well as built-in nested templates will all be instantiated.
      Therefore, a built-in report template can be easily extended from a DeepDive app by adding app-specific nested templates.
      For example, `variable/new-metric` in the app extends the built-in `variable` template.

* **Ordering Nested Templates**.
  The instantiation order of the nested templates can be specified in a special file named `reports.order`.
    * Each line of the file should contain a glob pattern matching nested report templates under it.
    * At most one of the line may be wildcard `*`, which denotes the position for the rest of the paths not explicitly mentioned.
    * For example, `variable/reports.order` has the following lines, which orders the summary at the top and the built-in templates in a particular order at the bottom, so any app-specific ones appear first:
        ```
        summary
        *
        quality
        inference
        supervision
        feature
        candidate
        ```

    * Currently, there's a limitation that nested `reports.order` have no effect, and only the one at the top of the template directly mentioned from the dashboard configuration is taken into account.


For example, consider the "Variables" section of the previous dashboard configuration.
```bash
### dashboard configuration (instantiating each template individually)
section "Variables"
report variable/inference    variable=has_spouse.is_correct
report variable/supervision  variable=has_spouse.is_correct top_positive=10 top_negative=10
report variable/feature      variable=has_spouse.is_correct
report variable/candidate    variable=has_spouse.is_correct
```
This could be rewritten as a single line as shown below:
```bash
### dashboard configuration (instantiating group of nested templates)
section "Variables"
report variable              variable=has_spouse.is_correct top_positive=10 top_negative=10
```
Furthermore, when more templates are added to `variable`, they will also get produced automatically without adding numerous lines for every instantiation of `variable` in the dashboard configuration.





## Utilities for Report Templates

Several utilities are provided to the executables in report templates to simplify the writing of new report templates.

### For producing JSON
`report-values` command can be used for augmenting named values to the `report.json` file without dealing with JSON parsing and formatting.
For example, suppose `report.json` already had the following content:
```json
{"a":"foo", "b":"bar"}
```
Simply running `report-values x=1 y=2.34 b=true c=bar d='[1,"2","three"]'` will update `report.json` to have:
```json
{"a":"foo", "b":true, "x":1, "y":2.34, "c":"bar", "d":[1,"2","three"]}
```
As shown in this example, values passed as arguments can be a valid JSON formatted string, or they will be treated as a normal string.

### Running SQL queries
`run-sql` command runs a SQL query against the underlying database for the current DeepDive app, and outputs the result in tab-separated format.
Currently, only Postgres/Greenplum is supported (a thin wrapper for `psql -c "COPY ... TO STDOUT"`), and the DeepDive app must keep the database credentials in `env.sh` at its root.


### Including CSV/TSV data in HTML or Markdown
`html-table-for` command formats a given CSV or TSV file into an HTML table that can be included in Markdown documents.
For example, the following executable document runs a SQL query to retrieve 10 sample candidates and presents a table.
Note the extra `CSV HEADER` arguments to `run-sql` for producing a CSV format compatible with this command.
```
<!-- README.md.in -->

#### 10 Most Frequent Candidates
Here are the 10 most frequent candidates extracted by DeepDive:
<$
run-sql "
    SELECT words, COUNT(*) AS count
    FROM candidate_table
    GROUP BY words
    ORDER BY count DESC
    LIMIT 10
" CSV HEADER >top_candidates.csv

html-table-for top_candidates.csv
$>
```

It will produce a table that looks like the following:
<blockquote>
<h4>10 Most Frequent Candidates</h4>
Here are the 10 most frequent candidates extracted by DeepDive:
<table>
    <thead><tr><th>words</th><th>count</th></tr></thead>
    <tbody>
        <tr><td>foo</td><td>987</td></tr>
        <tr><td>bar</td><td>654</td></tr>
        <tr><td>...</td><td>...</td></tr>
    </tbody>
</table>
</blockquote>





## Built-in Report Templates

There are a few report templates built into Mindbender most DeepDive apps will find useful.

(TODO)

* `corpus`
* `variable`
    * `variable/summary`
    * `variable/quality`
    * `variable/inference`
    * `variable/supervision`
    * `variable/feature`
    * `variable/candidate`

