

### Calibration Plot for `pheno_mentions.is_correct`

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
            type: 'scatter',
            data: [ [0,0], [1,1] ],
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
