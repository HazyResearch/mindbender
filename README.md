MindBender
==========

Mindbender for iterative knowledge base construction with [DeepDive][].

## Synopsis
```
make polish

./examples/labeling/start-mindtagger.sh

@prefix@/bin/mindbender compile  examples/genomics-application.mb  examples/genomics-application.deepdive
@prefix@/bin/mindbender compile  examples/spouse-example.mb        examples/spouse-example.deepdive
```

[DeepDive]: http://deepdive.stanford.edu/

## Mindtagger

Mindtagger is an interactive data labeling tool.  Please refer to [the DeepDive documentation](http://deepdive.stanford.edu/doc/basics/labeling.html) for more details on how to use Mindtagger to estimate precision of DeepDive apps.  For marking up text documents in general, e.g., for recall estimation, please take a look at the example tasks for the moment: [`genomics-recall`](https://github.com/netj/mindbender/tree/master/examples/labeling/genomics-recall) and [`genomics-recall-relation`](https://github.com/netj/mindbender/tree/master/examples/labeling/genomics-recall-relation) in the source tree.  They can be launched using the following script:

```bash
./examples/labeling/start-mindtagger.sh
```
