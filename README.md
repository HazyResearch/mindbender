MindBender
==========

MindBender for iterative knowledge base development with [DeepDive][].

## Synopsis
```
make polish

@prefix@/bin/mindbender tagger examples/genomics/mindtagger.conf

@prefix@/bin/mindbender compile  examples/genomics-application.mb  examples/genomics-application.deepdive
@prefix@/bin/mindbender compile  examples/spouse-example.mb        examples/spouse-example.deepdive
```

[DeepDive]: http://deepdive.stanford.edu/
