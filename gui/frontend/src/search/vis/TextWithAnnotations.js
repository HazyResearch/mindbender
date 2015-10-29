
var TextWithAnnotations = (function() {
  var create = function(obj) {
    content = obj._source.content
    var extractions_str = obj._source.extractions
    var extractions = []
    var transitions = []
    if (extractions_str) {
      var ex = JSON.parse(extractions[i]);
      extraction_id = extractions.length;
      extractions.push(ex)
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
       ex.selections = sels

       // add transitions
       for (var j=0; j < sels; j++) {
         transitions.push({ 
           'type':'start',
           'pos': sels[j][0],
           'extraction_id': extraction_id })
         transitions.push({
           'type':'end',
           'pos': sels[j][1],
           'extraction_id': extraction_id })
       }
    }

    transitions.sort(function(s,t) {
       return s.pos - t.pos;
    })

    // group transitions at same position
    var grouped_transitions = []
    var cur_group = { pos:-1, transitions: []}    

    for (var j=0; j < transitions; j++) {
      var t = transitions[j]
      if (t.pos == cur_group.pos) {
        cur_group.transitions.push(t)
      } else {
        if (cur_group.pos != -1) {
          grouped_transitions.push(cur_group);
        }
        cur_group = { pos:t.pos, transitions: [ t ]}
      }
    }
    if (cur_group.pos != -1) {
      grouped_transitions.push(cur_group)
    }

    // create segments
    var html = content; // the original html 
    var html_hl = ''

    function write_segment(start, end, spans) {
       var keys = Object.keys(spans)
       var str = html.substring(start, end)
       for (var k=0; k < keys.length; k++) {
         str = '<span>' + str + '</span>'
       }
       html_hl += str
    }

    var active_spans = {}
    var start = 0
    for (var j=0; j < grouped_transitions; j++) {
      var gt = grouped_transitions[j]
      write_segment(start, gt.pos, active_spans)
      // update active spans for next segment
      for (var k=0; k < gt.transitions.length; k++) {
        var t = gt.transitions[k]
        if (t.type == 'start') {
          active_spans[t.extraction_id] = true
        else
          delete active_spans[t.extraction_id]
        }
      }
      start = gt.pos
    }
    // final segment
    write_segment(start, html.length, active_spans)

    var content = html_hl

    var el = $('<div></div>')
        .append($('<span></span>'))
            .attr({'style':'white-space:pre-wrap'})
            .append(jQuery.parseHTML(content))

    /*
    var extractions = obj._source.extractions
    if (extractions) { 
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
      
    }*/
    return el
  }

  return {
    create: create
  }

})()

