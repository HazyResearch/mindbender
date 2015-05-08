`
function ReportChart(json) {
	this.json = json;

	this.x_label = json.x;
	this.y_label = json.y;
	this.data = [];

	var dimensions = [json.x, json.y];

	for (var x = 0; x < json.data.length; x++) {
		var e = [];
		for (var y = 0; y < dimensions.length; y++) {
			var index = json.headers.indexOf(dimensions[y]);
			e.push(json.data[x][index]);
		}
		this.data.push(e);
	}
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
	
	if (bucket_size == 1) {
		for (var x in this.data) {
			buckets.push(this.data[x][1]);
			labels.push(this.data[x][0]);
		}
	}
	else {
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

ReportChart.prototype.axisIsNumeric = function(axis) {
	var axisIndexes = {x: 0, y: 1};
	var index = axisIndexes[axis];

	for (var x = 0; x < this.data.length; x++) {
		if (isNaN(this.data[x][index])) {
			return false;
		}
	}

	return true;
}

window.ReportChart = ReportChart;
`
