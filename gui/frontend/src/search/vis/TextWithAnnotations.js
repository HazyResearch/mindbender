
var TextWithAnnotations = (function() {
  var create = function(obj) {
    content = obj._source.content

    var el = $('<div></div>')
        .append($('<span></span>'))
            .attr({'style':'white-space:pre-wrap'})
            .append(jQuery.parseHTML(content))

    var extractions = obj._source.extractions
    if (typeof extractions !== 'undefined') { 
      for (var i=0; i < extractions.length; i++) {
         var ex = JSON.parse(extractions[i]);
         // see if we should merge multiple selections into a
         // a single one, we merge if there's only one char in
         // between and it's part of the same extraction
         var sels = []
         for (var j=0; j < ex.selections.length; j++) {
            if (sels.length > 0) {
               var prev_end = sels[sels.length-1][1]
               var next_sta = ex.selections[j][0]
               if (next_sta - prev_end <= 1) {
                  sels[sels.length-1][1] = ex.selections[j][1]
                  continue
               }
            }
            sels.push(ex.selections[j])
         }

         new SpansVisualization(el[0], sels, ex.extractor)
      }
    }
    return el
  }

  return {
    create: create
  }

})()

