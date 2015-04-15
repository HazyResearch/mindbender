`
function ReportChart(json) {
	this.json = json;
	
	var keys = Object.keys(json.data[0]);
	this.x_label = keys[0];
	this.y_label = keys[1];
	this.data = json.data.map(function(point) { return [point[keys[0]], point[keys[1]]] });
}


ReportChart.prototype.areaChart = function(chart) {
	var self = this;
	$("#"+chart).highcharts({
		chart: {
			type: 'area'
		},
		title: {
			text: '',
		},
		yAxis: {
			min: 1,
			title: {
				text: this.y_label
			},
			type: 'logarithmic',
		},
		xAxis: {
			type: 'logarithmic'
		},
		tooltip: {
			formatter: function() {
				return '<b>' + this.x + ' ' + self.x_label + ' </b><br>' + this.y.toLocaleString() + ' ' + self.y_label
			}
		},
		series: [{
			name: self.x_label,
			data: self.data
		}]
	});
}

ReportChart.prototype.scatterPlot = function(chart) {
	var self = this;
	
	$("#"+chart).highcharts({
		chart: {
			type: 'scatter'
		},
		title: {
			text: '',
		},
		yAxis: {
			min: 1,
			title: {
				text: this.y_label
			},
			type: 'logarithmic',
		},
		xAxis: {
			type: 'logarithmic'
		},
		tooltip: {
			formatter: function() {
				return '<b>' + this.x + ' ' + self.x_label + ' </b><br>' + this.y.toLocaleString() + ' ' + self.y_label
			}
		},
		series: [{
			name: self.x_label,
			data: self.data
		}]
	});
}

ReportChart.prototype.histogram = function(chart, num_bins) {
	var bins = this.binData(num_bins);
	
	var self = this;
	$("#"+chart).highcharts({
		chart: {
			type: 'column'
		},
		title: {
			text: '',
		},
		yAxis: {
			title: {
				text: self.y_label
			},
			type: 'logarithmic',
			min: 1
		},
		xAxis: {
			categories: bins.labels,
			labels: {
				rotation: -45
			}
		},
		tooltip: {
			formatter: function() {
				return '<b>' + this.x + ' ' + self.x_label + ' </b><br>' + this.y.toLocaleString() + ' ' + self.y_label
			}
		},
		series: [{
			name: self.x_label,
			data: bins.buckets
		}]
	});
}

ReportChart.prototype.binData = function(num_bins) {
	// Quick binning algorithm, given the number of bins
	var bucket_size = Math.ceil(this.data.length/num_bins);
	var labels = [], buckets = [], i = 0, bucket = 0;
	var previous_label = this.data[0][0];
	
	for (var x in this.data) {
		if (i >= bucket_size) {
			buckets.push(bucket);
			labels.push(previous_label.toLocaleString() + " - " + (this.data[x][0]-1).toLocaleString());
			previous_label = this.data[x][0];
			bucket = 0;
			i = 0;
		}
		bucket += this.data[x][1];
		i++;
	}
	if (bucket > 0) {
		buckets.push(bucket);
		labels.push(previous_label.toLocaleString() + " - " + this.data[x][0].toLocaleString());
	}

	return {buckets: buckets, labels: labels};
}



ReportChart.prototype.buildTable = function(id) {
	var table = "<table><tr><th>" + this.json.x + "</th><th>" + this.json.y + "</th></tr>";
	for (var x = 0; x < this.json.data.length; x++) {
		table += "<tr><td>" + this.json.data[x][this.x_label] + "</td><td>" + this.json.data[x][this.y_label] + "</td></tr>";
	}
	table += "</table>";
	document.getElementById(id).innerHTML = table;	
}

window.ReportChart = ReportChart;
`
