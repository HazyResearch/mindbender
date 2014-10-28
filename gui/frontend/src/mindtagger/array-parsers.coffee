angular.module 'mindbenderApp.mindtagger.arrayParsers', [
]

# a handy filter for parsing Postgres ARRAYs serialized in CSV outputs
.filter 'parsedPostgresArray', ->
    (text, index) ->
        # extract the csv-like piece in the text
        return null unless text? and (m = /^{(.*)}$/.exec text?.trim())?
        csvLikeText = m[1]
        # convert backslash escapes to standard CSV escapes
        csvText = csvLikeText
            .replace /\\(.)/g, "$1"
            .replace /\\(.)/g, (m, c) ->
                switch c
                    when '"'
                        '""'
                    else
                        c
        array =
            try $.csv.toArray csvText
            catch err
                console.error "csv parse error", text, csvLikeText, csvText, err
                [text]
        if index?
            array[index]
        else
            array

.filter 'parsedPythonArray', ->
    (text, index) ->
        return null unless text? and (m = /^\[(.*)\]$/.exec text?.trim())?
        array = []
        headTailRegex = ///^
                '([^']*)'  # head # FIXME handle escaping problem
                (, (.*))?  # optional tail
            $///
        remainder = m[1].trim()
        while remainder?.length > 0
            if (m = headTailRegex.exec remainder)?
                array.push m[1]
                remainder = m[3]?.trim()
            else
                return [text]
        array

.filter 'parsedArray', (parsedPostgresArrayFilter, parsedPythonArrayFilter) ->
    (text, format) ->
        switch format
            when "postgres"
                parsedPostgresArrayFilter text
            when "python"
                parsedPythonArrayFilter text
            else # when "json"
                try JSON.parse text
                catch err
                    console.error err
                    [text]
