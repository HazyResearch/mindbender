# snapshot/20150216-13
Produced: 2015-02-16T16:00:14


# Variables


# Variable gene_mentions.is_correct




## Quality Metrics

### Inference
* Precision estimate = **...**
* Recall estimate = **...**
* F-1 score estimate = **...**

### Candidate Extraction
* Precision = **...**
* Recall = **...**




## Inference

* **1,391,742** extractions (candidates with expectation > 0.90)

* **27,969** distinct extractions


* **105,358** documents with extractions



### Most frequent extractions
<table class="table table-stripped">
<thead><tr>
<th>words</th>
<th>count</th>
</tr></thead>
<tbody>
<tr><td>{insulin}</td><td>57198</td></tr>
<tr><td>{albumin}</td><td>21646</td></tr>
<tr><td>{interferon}</td><td>17516</td></tr>
<tr><td>{EGFR}</td><td>16773</td></tr>
<tr><td>{p53}</td><td>14837</td></tr>
<tr><td>{VEGF}</td><td>13518</td></tr>
<tr><td>{EGF}</td><td>12889</td></tr>
<tr><td>{TNF}</td><td>11289</td></tr>
<tr><td>{tumor,necrosis,factor}</td><td>11095</td></tr>
<tr><td>{CD4}</td><td>10640</td></tr>
</tbody>
</table>





## Supervision

* **1,318,084** positively labeled candidates
* **4,439,582** negatively labeled candidates
* **17,723,967** unlabeled candidates

<!--
* TODO scatter plot showing distribution of positive/negative candidates firing top k frequent features
    * with opacity proportional to #supervised / #fired
    * with size or color intensity proportional to #fired
-->



## Feature Extraction
* ? features
* ? distinct features
* ? mentions per feature



## Candidate Extraction

* **18,045,349** candidates

* **44,398** distinct candidates


* **168,044** documents with candidates



### Most frequent candidates
<table class="table table-stripped">
<thead><tr>
<th>words</th>
<th>count</th>
</tr></thead>
<tbody>
<tr><td>{S1}</td><td>377034</td></tr>
<tr><td>{S2}</td><td>209654</td></tr>
<tr><td>{CD4}</td><td>187479</td></tr>
<tr><td>{S3}</td><td>133236</td></tr>
<tr><td>{CD8}</td><td>116488</td></tr>
<tr><td>{insulin}</td><td>114205</td></tr>
<tr><td>{p53}</td><td>105364</td></tr>
<tr><td>{SA}</td><td>97637</td></tr>
<tr><td>{SE}</td><td>97624</td></tr>
<tr><td>{PA}</td><td>97264</td></tr>
</tbody>
</table>




# Variable hpoterm_mentions.is_correct




## Quality Metrics

### Inference
* Precision estimate = **...**
* Recall estimate = **...**
* F-1 score estimate = **...**

### Candidate Extraction
* Precision = **...**
* Recall = **...**




## Inference

* **1,269,415** extractions (candidates with expectation > 0.90)

* **14,361** distinct extractions


* **98,533** documents with extractions



### Most frequent extractions
<table class="table table-stripped">
<thead><tr>
<th>words</th>
<th>count</th>
</tr></thead>
<tbody>
<tr><td>{prostate,cancer}</td><td>42526</td></tr>
<tr><td>{stroke}</td><td>41019</td></tr>
<tr><td>{melanoma}</td><td>40070</td></tr>
<tr><td>{schizophrenia}</td><td>35689</td></tr>
<tr><td>{fever}</td><td>33980</td></tr>
<tr><td>{asthma}</td><td>33004</td></tr>
<tr><td>{leukemia}</td><td>28781</td></tr>
<tr><td>{insulin,resistance}</td><td>24870</td></tr>
<tr><td>{pneumonia}</td><td>21397</td></tr>
<tr><td>{glioma}</td><td>20236</td></tr>
</tbody>
</table>





## Supervision

* **1,168,336** positively labeled candidates
* **324,494** negatively labeled candidates
* **1,335,269** unlabeled candidates

<!--
* TODO scatter plot showing distribution of positive/negative candidates firing top k frequent features
    * with opacity proportional to #supervised / #fired
    * with size or color intensity proportional to #fired
-->



## Feature Extraction
* ? features
* ? distinct features
* ? mentions per feature



## Candidate Extraction

* **1,421,771** candidates

* **24,002** distinct candidates


* **106,539** documents with candidates



### Most frequent candidates
<table class="table table-stripped">
<thead><tr>
<th>words</th>
<th>count</th>
</tr></thead>
<tbody>
<tr><td>{stroke}</td><td>43410</td></tr>
<tr><td>{prostate,cancer}</td><td>42697</td></tr>
<tr><td>{melanoma}</td><td>41613</td></tr>
<tr><td>{schizophrenia}</td><td>36993</td></tr>
<tr><td>{fever}</td><td>34876</td></tr>
<tr><td>{asthma}</td><td>34187</td></tr>
<tr><td>{leukemia}</td><td>29855</td></tr>
<tr><td>{insulin,resistance}</td><td>25758</td></tr>
<tr><td>{pneumoniae}</td><td>23828</td></tr>
<tr><td>{pneumonia}</td><td>22370</td></tr>
</tbody>
</table>



