Mindbender
==========

Mindbender is a set of tools for iterative knowledge base construction with [DeepDive][].

## Synopsis
#### Installation

1. Download [a release of Mindbender](https://github.com/netj/mindbender/releases).
2. Mark the downloaded file as executable (by running `chmod +x mindbender-*.sh`).
3. Place it into a directory that is on the `$PATH` environment (e.g., `/usr/local/bin/mindbender`), also renaming it so you can simply type `mindbender` later.

Alternatively, you can build and install from source by running `make install PREFIX=/usr/local`.


#### Latest Example
See [examples/spouse_example](https://github.com/HazyResearch/mindbender/tree/master/examples/spouse_example#readme) for more details about using the tools included in Mindbender.

----

#### Launch Mindtagger for labeling data
```bash
mindbender tagger examples/labeling/**/mindtagger.conf
# See-also: ./examples/labeling/start-mindtagger.sh
```

#### Take snapshots of your DeepDive app, producing various reports
```bash
cd your-deepdive-app
mindbender snapshot
open snapshot/LATEST/README.md
```

#### Launch Dashboard to use the reports interactively for deeper error analysis
```bash
cd your-deepdive-app
mindbender dashboard
```

There are some examples included in this source tree:
```bash
cd examples/dashboard/spouse_example
mindbender dashboard
```


[DeepDive]: http://deepdive.stanford.edu/


## Mindtagger

Mindtagger is an interactive data labeling tool.  Please refer to [the DeepDive documentation](http://deepdive.stanford.edu/doc/basics/labeling.html) for more details on how to use Mindtagger to estimate precision of DeepDive apps.  For marking up text documents in general, e.g., for recall estimation, please take a look at the example tasks for the moment: [`genomics-recall`](https://github.com/netj/mindbender/tree/master/examples/labeling/genomics-recall) and [`genomics-recall-relation`](https://github.com/netj/mindbender/tree/master/examples/labeling/genomics-recall-relation) in the source tree.  They can be launched using the following script:

```bash
./examples/labeling/start-mindtagger.sh
```
