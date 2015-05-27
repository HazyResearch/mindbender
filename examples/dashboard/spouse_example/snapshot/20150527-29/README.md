# snapshot/20150527-29
Produced: 2015-05-27T15:06:42



* **958** documents
* **43,789** sentences


# Variable `has_spouse.is_true`




## Candidate Extraction

* **75,422** candidates

* **54,846** distinct candidates


* **0** documents with candidates





## Feature Extraction


* **1,160,450** features
* **16,933** distinct features






## Supervision

* **2,164** positively labeled candidates
* **3,772** negatively labeled candidates
* **69,486** unlabeled candidates

<!--
* TODO scatter plot showing distribution of positive/negative candidates firing top k frequent features
    * with opacity proportional to #supervised / #fired
    * with size or color intensity proportional to #fired
-->



<div>
<chart
    data-file="supervision_distribution"
    type="bubble"
    point-name="feature"
    x-axis="positive"
    x-label="#Positive"
    y-axis="negative"
    y-label="#Negative"
    z-axis="unsupervised"
    z-label="#Unsupervised"
    highcharts-options='
    {"xAxis":{"min":0,"max":3374},"yAxis":{"min":0,"max":3374},"plotOptions":{"bubble":{"tooltip":{"pointFormat":"<b>{point.name}</b><br>{point.x} positive<br>{point.y} negative<br>{point.z} unsupervised"}}},"series":[{"name":"Balanced","type":"scatter","data":[[0,0],[3374,3374]],"marker":{"enabled":false},"enableMouseTracking":false,"lineWidth":1,"color":"#00c","dashStyle":"ShortDash"}]}
    '
></chart>
</div>



## Inference

* **36,025** extractions (candidates with expectation > 0.90)

* **28,690** distinct extractions


* **0** documents with extractions




### Calibration Plot for `has_spouse.is_true`

<div class="row text-center">
<div class="col-sm-4">
<!-- accuracy -->
(a) Accuracy (Testing Set)
<chart
    data-file="calibration"
    type="scatter"
    x-axis="probability"
    x-label="Probability"
    y-axis="accuracy"
    y-label="Accuracy"
    highcharts-options="{
        yAxis: { min: 0, max: 1 },
        xAxis: { min: 0, max: 1 },
        legend: { enabled: false },
        plotOptions: {
            scatter: {
                lineWidth: 1,
                color: '#f00'
            }
        },
        series: [{
            name: 'Balanced',
            type: 'scatter',
            data: [ [0,0], [1,1] ],
            marker: { enabled: false }, enableMouseTracking: false,
            lineWidth: 1,
            color: '#00c',
            dashStyle: 'ShortDash'
        }]
    }"
></chart>
</div>

<div class="col-sm-4">
<!-- #predictions histogram (test set) -->
(b) # Predictions (Testing Set)
<chart
    data-file="calibration"
    type="bar"
    x-axis="probability"
    x-label="Probability"
    y-axis="num_predictions_test"
    y-label="#Predictions"
></chart>
</div>

<div class="col-sm-4">
<!-- #predictions histogram (whole set) -->
(c) # Predictions (Whole Set)
<chart
    data-file="calibration"
    type="bar"
    x-axis="probability"
    x-label="Probability"
    y-axis="num_predictions_whole"
    y-label="#Predictions"
></chart>
</div>

</div>

<div class="text-center">
(a) and (b) are produced using hold-out on evidence variables; (c) also includes all non-evidence variables.
</div>

