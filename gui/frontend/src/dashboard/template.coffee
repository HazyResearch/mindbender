`
function Template() {
}

Template.addVariable = function(img) {
	var table = $(img).parent().find("table");
	var num = $(table).find("tr").length - 1;
	
	$(table).append('<tr>' +
		'<td>$<input type="text" name="variable[' + num + '][name][]"></td>' +
		'<td>$<input type="text" name="variable[' + num + '][default][]"></td>' +
	'</tr>');
}

Template.addTemplate = function() {
	$.get("configure_template.html", function(data) {
		var num = $(".template").length+1;
		$(".templates").append(num + '.)' + data);
		Template.addBindings();
	});
	
}

Template.addBindings = function() {
	$(".template-format").change(function() {
		$(this).parent().parent().find(".formatted").toggle();
		$(this).parent().parent().find(".custom").toggle();
	});
}
`
