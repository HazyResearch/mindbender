
var TextWithAnnotations = (function() {
  var create = function(obj) {
    content = obj._source.content

    var el = $('<div></div>')
        .append($('<span></span>'))
            .attr({'style':'white-space:pre-wrap'})
            .append(jQuery.parseHTML(content))

    var extractions = obj._source.extractions 
    for (var i=0; i < extractions.length; i++) {
       var ex = JSON.parse(extractions[i]);
       new SpansVisualization(el[0], ex.selections, ex.extractor)
    }
    return el
  }

  return {
    create: create
  }

})()

