

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
