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
        remainder = m[1].trim()
        array = []
        headTailRegex = ///^
                (['"])   # Match an opening quote (group 2)
                (        # Match and capture into group 3:
                 (?:     # the following regex:
                  \\.    # Either an escaped character
                 |       # or
                  (?!\1) # (as long as we're not right at the matching quote)
                  .      # any other character.
                 )*      # Repeat as needed
                )        # End of capturing group
                \1       # Match the corresponding closing quote.
                (?:, (.*))?  # optional tail
            $///
        while remainder?.length > 0
            if (m = headTailRegex.exec remainder)?
                head = m[2]
                # TODO handle escape codes, e.g., \xYZ
                head = head.replace /// \\(.) ///g, "$1"
                array.push head
                remainder = m[3]?.trim()
            else
                return [text]
        array

.filter 'parsedArray', ($filter) ->
    (text, format) ->
        switch format
            when "postgres"
                ($filter "parsedPostgresArray") text
            when "python"
                ($filter "parsedPythonArray") text
            else # when "json"
                try JSON.parse text
                catch err
                    console.error err
                    [text]

.filter 'concatArray', (parsedArrayFilter) ->
    (text, format, delim = " ") ->
        ((parsedArrayFilter text, format)?.join delim) ? text

