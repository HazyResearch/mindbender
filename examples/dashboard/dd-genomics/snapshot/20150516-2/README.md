# snapshot/20150516-2
Produced: 2015-05-16T05:58:49



## Candidate Extraction

* **233** candidates

* **120** distinct candidates


* **55** documents with candidates





## Feature Extraction


* **8,038** features
* **3,470** distinct features






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



## Quality Metrics

### Inference
* Precision estimate = **...**
* Recall estimate = **...**
* F-1 score estimate = **...**

### Candidate Extraction
* Precision = **...**
* Recall = **...**




## Inference

* **0** extractions (candidates with expectation > 0.90)

* **0** distinct extractions


* **0** documents with extractions




### Top 10 Positively Weighted Features
<table class="table table-stripped">
<thead><tr>
<th>weight</th>
<th>description</th>
</tr></thead>
<tbody>
<tr><td>0</td><td>gene_inference-W_LEMMA_L_1_R_2_[RESEARCH]_[be submit]</td></tr>
<tr><td>0</td><td>gene_inference-W_RIGHT_3_[( no posttranslational]</td></tr>
<tr><td>0</td><td>gene_inference-W_NER_L_1_R_1_[MISC]_[NUMBER]</td></tr>
<tr><td>0</td><td>gene_inference-W_LEMMA_L_3_R_2_[this reason ,]_[, like]</td></tr>
<tr><td>0</td><td>gene_inference-W_RIGHT_2_[and t1r2]</td></tr>
<tr><td>0</td><td>gene_inference-W_LEMMA_L_3_R_1_[AE , Horvitz]_[,]</td></tr>
<tr><td>0</td><td>gene_inference-W_LEMMA_L_3_R_2_[, ribosomal protein]_[, and]</td></tr>
<tr><td>0</td><td>gene_inference-W_LEFT_3_[_NUMBER that the]</td></tr>
<tr><td>0</td><td>gene_inference-W_LEMMA_L_2_R_1_[interaction between]_[or]</td></tr>
<tr><td>0</td><td>gene_inference-W_LEMMA_L_1_R_3_[a]_[reference ( each]</td></tr>
</tbody>
</table>


### Top 10 Negatively Weighted Features
<table class="table table-stripped">
<thead><tr>
<th>weight</th>
<th>description</th>
</tr></thead>
<tbody>
<tr><td>-1.60188</td><td>gene_inference-STARTS_WITH_CAPITAL</td></tr>
<tr><td>-1.43444</td><td>gene_inference-LENGTH_0</td></tr>
<tr><td>-1.35974</td><td>gene_inference-NER_SEQ_[O]</td></tr>
<tr><td>-1.20403</td><td>pheno_inference-W_LEFT_NER_1_[O]</td></tr>
<tr><td>-1.20187</td><td>gene_inference-W_LEFT_NER_1_[O]</td></tr>
<tr><td>-1.15067</td><td>pheno_inference-NER_SEQ_[O]</td></tr>
<tr><td>-0.893688</td><td>gene_inference-W_RIGHT_NER_1_[O]</td></tr>
<tr><td>-0.882311</td><td>pheno_inference-W_LEFT_NER_2_[O O]</td></tr>
<tr><td>-0.86591</td><td>gene_inference-POS_SEQ_[NN]</td></tr>
<tr><td>-0.768365</td><td>pheno_inference-W_RIGHT_NER_1_[O]</td></tr>
</tbody>
</table>





## Quality Metrics

### Inference
* Precision estimate = **...**
* Recall estimate = **...**
* F-1 score estimate = **...**

### Candidate Extraction
* Precision = **...**
* Recall = **...**



# Variable pheno_mentions.is_correct




## Supervision

* **0** positively labeled candidates
* **42** negatively labeled candidates
* **191** unlabeled candidates

<!--
* TODO scatter plot showing distribution of positive/negative candidates firing top k frequent features
    * with opacity proportional to #supervised / #fired
    * with size or color intensity proportional to #fired
-->



## Candidate Extraction

* **3,380** candidates

* **525** distinct candidates


* **69** documents with candidates





## Feature Extraction


* **106,531** features
* **25,027** distinct features






### Calibration Plot for `gene_mentions.is_correct`

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



## Quality Metrics

### Inference
* Precision estimate = **...**
* Recall estimate = **...**
* F-1 score estimate = **...**

### Candidate Extraction
* Precision = **...**
* Recall = **...**




## Inference

* **0** extractions (candidates with expectation > 0.90)

* **0** distinct extractions


* **0** documents with extractions




### Top 10 Positively Weighted Features
<table class="table table-stripped">
<thead><tr>
<th>weight</th>
<th>description</th>
</tr></thead>
<tbody>
<tr><td>0</td><td>gene_inference-W_LEMMA_L_1_R_2_[RESEARCH]_[be submit]</td></tr>
<tr><td>0</td><td>gene_inference-W_RIGHT_3_[( no posttranslational]</td></tr>
<tr><td>0</td><td>gene_inference-W_NER_L_1_R_1_[MISC]_[NUMBER]</td></tr>
<tr><td>0</td><td>gene_inference-W_LEMMA_L_3_R_2_[this reason ,]_[, like]</td></tr>
<tr><td>0</td><td>gene_inference-W_RIGHT_2_[and t1r2]</td></tr>
<tr><td>0</td><td>gene_inference-W_LEMMA_L_3_R_1_[AE , Horvitz]_[,]</td></tr>
<tr><td>0</td><td>gene_inference-W_LEMMA_L_3_R_2_[, ribosomal protein]_[, and]</td></tr>
<tr><td>0</td><td>gene_inference-W_LEFT_3_[_NUMBER that the]</td></tr>
<tr><td>0</td><td>gene_inference-W_LEMMA_L_2_R_1_[interaction between]_[or]</td></tr>
<tr><td>0</td><td>gene_inference-W_LEMMA_L_1_R_3_[a]_[reference ( each]</td></tr>
</tbody>
</table>


### Top 10 Negatively Weighted Features
<table class="table table-stripped">
<thead><tr>
<th>weight</th>
<th>description</th>
</tr></thead>
<tbody>
<tr><td>-1.60188</td><td>gene_inference-STARTS_WITH_CAPITAL</td></tr>
<tr><td>-1.43444</td><td>gene_inference-LENGTH_0</td></tr>
<tr><td>-1.35974</td><td>gene_inference-NER_SEQ_[O]</td></tr>
<tr><td>-1.20403</td><td>pheno_inference-W_LEFT_NER_1_[O]</td></tr>
<tr><td>-1.20187</td><td>gene_inference-W_LEFT_NER_1_[O]</td></tr>
<tr><td>-1.15067</td><td>pheno_inference-NER_SEQ_[O]</td></tr>
<tr><td>-0.893688</td><td>gene_inference-W_RIGHT_NER_1_[O]</td></tr>
<tr><td>-0.882311</td><td>pheno_inference-W_LEFT_NER_2_[O O]</td></tr>
<tr><td>-0.86591</td><td>gene_inference-POS_SEQ_[NN]</td></tr>
<tr><td>-0.768365</td><td>pheno_inference-W_RIGHT_NER_1_[O]</td></tr>
</tbody>
</table>





## Quality Metrics

### Inference
* Precision estimate = **...**
* Recall estimate = **...**
* F-1 score estimate = **...**

### Candidate Extraction
* Precision = **...**
* Recall = **...**



# Variable gene_mentions.is_correct




## Supervision

* **0** positively labeled candidates
* **148** negatively labeled candidates
* **3,232** unlabeled candidates

<!--
* TODO scatter plot showing distribution of positive/negative candidates firing top k frequent features
    * with opacity proportional to #supervised / #fired
    * with size or color intensity proportional to #fired
-->



* **73** documents
* **10,000** sentences

