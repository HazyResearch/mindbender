# DeepDive Dashboard

Mindbender provides an interactive dashboard for understanding the state of a DeepDive app.
The dashboard presents a set of *reports* showing aggregate statistics and sampled data products collected from a run of a DeepDive app.
Many common reports bundled with Mindbender can be easily customized or excluded, and user-defined reports that show app-specific metrics can be produced without much hassle.

In this document, we describe how Mindtagger interacts with the target DeepDive app to take snapshots for the dashboard.
Then, we define what interface individual report templates should expose to the Mindbender dashboard, and describe how the templates are used for assembling a complete set of reports.


## DeepDive Snapshots

Every time a DeepDive app is run with Mindbender, a *snapshot* is taken under `snapshots/` of the target app with a unique name beginning with the date it was run, e.g., `snapshots/20150206-1/`.
Each snapshot contains a set of reports, each of which summarizes an aspect about the data products in the DeepDive run or the code that produced them.
Alongside the reports, copies of important DeepDive artifacts, such as the `application.conf` and extractor code are automatically preserved for future reference.


## Report Template
Each report in a snapshot is produced by a *report template*.

* A report template is a directory that resides under either:
    * `report-templates/` of the target DeepDive app (app-specific), or
    * `dashboard/report-templates/` of Mindbender's source tree (bundled).
* It must contain an executable file named `report.sh`, but may contain as many extra files as it needs.
* It takes zero or more named parameters (i.e., name=value pairs).
  Therefore a template may be instantiated with different set of parameters to produce multiple reports.
  Where these parameters are specified will be explained later.

### How Each Report Is Produced

1. A template directory is cloned into the current snapshot directory, preserving the relative path after `report-templates/`.
    * This cloned directory is a *report instance* directory, or simply called as a *report*.
    * If a report template is instantiated more than once, the path of the report will be suffixed with a serial number or string resembling the parameters, to isolate each report from others.
2. `report.sh` of the report instance is executed under a controlled environment:
    * All named parameters for the report are declared as environment variables.
    * Current working directory is set to the report instance directory.
    This localizes file accesses of `report.sh`, simplifying reading files included in the template as well as generating new ones for the report without referring to any global path or variables.

### What Each Report Must Contain After Production

* `README.md` -- a human-readable content of the report in Markdown syntax.
* `report.json` -- a machine-readable content of the report in JSON format, which contains the metadata of report as well as other useful structured data.


## Dashboard Configuration

The list of reports each new snapshot should produce can be enumerated in a *dashboard configuration*.

* A dashboard configuration is a plain text file named `reports.conf` that resides at the root of the target DeepDive app.
* Any text after a `#` character are ignored, so comments can be placed.
* Each of its line contains either:
    * `section` followed by a section title, or
    * `report` followed by the report template name and zero or more named parameters separated by white space.
* Each time a new snapshot is created, a copy of this dashboard configuration will be retained as the reports it enumerates are produced.
* Also, a snapshot-level `README.md` is produced at the top of the snapshot directory, which links to every reports produced for the snapshot.

Here's an example that produces four reports.
```bash
### dashboard configuration

# show statistics about the corpus stored in table "sentences"
report corpus/stats    table=sentences column_document=doc_id column_sentence=sent_id

section Variables
report variables/stats             table=has_spouse column=is_correct
report variables/calibration_plot  table=has_spouse column=is_correct

section Features
report features/sample_by_weight    top_positive=10 top_negative=10
```


## Composite Report Template
A composite report template is a report template that instantiates other report templates.

* A report template that produces a file named `reports.conf` is a composite report template.
* The `reports.conf` should have identical syntax to the dashboard configuration.
* The lines in the `reports.conf` are interpreted as if they followed the line instantiating the composite report template.

For example, suppose there's a composite report template named `variables/overview` that produces a `reports.conf` for parameter `variable=X.Y` as follows:
```bash
### variables/overview/reports.conf
report variables/stats             table=X column=Y
report variables/calibration_plot  table=X column=Y
```
Then, the two lines for `section Variable` in the previous example for dashboard configuration can be abbreviated as:
```bash
### dashboard configuration
report variables/overview  variable=has_spouse.is_correct
```
Therefore, as new variables are introduced, group of reports can be easily configured from the dashboard configuration:
```bash
### dashboard configuration (expanded to report two more variables)
report variables/overview  variable=has_spouse.is_correct

report variables/overview  variable=is_sibling_of.is_correct    # added
report variables/overview  variable=is_parent_of.is_correct     # added
```
Moreover, each group of reports can evolve independently without impacting the complexity of the dashboard configuration:
```bash
### variables/overview/reports.conf (evolved to have two more reports)
report variables/stats             table=X column=Y
report variables/calibration_plot  table=X column=Y

report variables/features          table=X column=Y     # added
report variables/supervision       table=X column=Y     # added
```

