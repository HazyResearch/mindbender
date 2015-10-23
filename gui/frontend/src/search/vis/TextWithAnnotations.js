
var TextWithAnnotations = (function() {
  var create = function(obj) {
    content = obj._source.content

    var el = $('<div></div>')
        .append($('<span></span>'))
            .attr({'style':'white-space:pre-wrap'})
            .append(jQuery.parseHTML(content))

    // compute correct char offsets when there
    // are HTML tags (which we interpret)
    var curchar = 0
    var charmap = []
    var in_tag = false
    for (var i=0; i < content.length; i++) {
       if (!in_tag && content[i] == '<')
           in_tag = true;

       charmap.push(curchar)
       if (!in_tag) curchar += 1;

       if (in_tag && content[i] =='>')
           in_tag = false;
    }

    var extractions = obj._source.extractions 
    for (var i=0; i < extractions.length; i++) {
       var ex = JSON.parse(extractions[i])

       for (var j=0; j < ex.selections.length; j++) {
          ex.selections[j][0] = charmap[ex.selections[j][0]];
          ex.selections[j][1] = charmap[ex.selections[j][1]];
       }
       new SpansVisualization(el[0], ex.selections)
    }
    return el
  }

  return {
    create: create
  }

})()

