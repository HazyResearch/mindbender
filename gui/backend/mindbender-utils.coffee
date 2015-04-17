## Mindbender utilities

util = require "util"
fs = require "fs-extra"
path = require "path"

_ = require "underscore"

{TSV,CSV} = require "tsv"
csv = require "csv"


exports.MindbenderUtils =
class MindbenderUtils
    # Expand all parameter references in the strings of given value.  Expansion
    # is done recursively to values and elements if it is a complex Object or
    # Array.
    @expandParameters: (value, params) ->
        return value unless params?
        expanded = (o) ->
            if "string" is typeof o
                o.replace ///
                        [$][{]   # begin string '${'
                        ([^{}]+) #  parameter name may not include { or }
                        [}]      # end string '}'
                    ///g, (m, name) ->
                        params[name] ? m
            else if o instanceof Array
                expanded v for v in o
            else if "object" is typeof o
                eo = {}
                for k,v of o
                    eo[k] = expanded v
                eo
            else
                o
        expanded value

    @escapeSqlString: (s) ->
        s?.replace /'/g, "''"
    @escapeSqlName: (n) ->
        # use double quote to escape SQL names
        "\"#{n?.replace /"/g, "\"\""}\""
    @asSqlLiteral: (value) ->
        if value?
            switch typeof value
                when "object"
                    "'#{MindbenderUtils.escapeSqlString (JSON.stringify value)}'"
                when "number"
                    if _.isNaN value
                        "NULL"
                    else
                        "#{value}"
                when "boolean"
                    if value then "TRUE" else "FALSE"
                else # when "string"
                    "'#{MindbenderUtils.escapeSqlString value}'"
        else
            "NULL"
    @findAllKeys: (objs) ->
        merged = {}
        _.extend merged, obj for obj in objs
        _.keys merged

    # some routines for loading and storing data
    @CSV_OPTIONS:
        columns: yes
        header: yes
        auto_parse: yes
    @convertValues: (array, from, to) ->
        if array?
            for row in array
                row[key] = to for key,value of row when (from? and value is from) or (not value? and not from?)
            array
    @deserializeNullStrings: (array) -> MindbenderUtils.convertValues array, "\\N", null
    @serializeNulls:         (array) -> MindbenderUtils.convertValues array, null, "\\N"
    @unescapeBackslashes: (array) ->
        if array?
            for row in array
                for key,value of row when "string" is typeof value
                    row[key] = value
                        .replace /\\(.)/g, (m, c) ->
                            switch c
                                when "t"
                                    "\t"
                                when "n"
                                    "\n"
                                else
                                    c
            array
    @escapeWithBackslashes: (array) ->
        if array?
            for row in array
                for key,value of row when "string" is typeof value
                    row[key] = value
                        .replace /([\t\n\\])/g, (m, c) ->
                            switch c
                                when "\t"
                                    "\\t"
                                when "\n"
                                    "\\n"
                                else
                                    "\\#{c}"
            array
    @loadDataFile: (fName, next) ->
        util.log "loading #{fName}"
        loaded = (err, data) ->
            if err
                util.log "error loading #{fName}"
            else
                util.log "loaded #{fName}"
            next err, data
        try
            switch path.extname fName
                when ".json"
                    fs.readFile fName, (err, data) ->
                        return loaded err if err
                        try loaded null, JSON.parse data
                        catch parseError then loaded parseError
                when ".tsv"
                    fs.readFile fName, (err, data) ->
                        return loaded err if err
                        try loaded null, MindbenderUtils.unescapeBackslashes (
                                MindbenderUtils.deserializeNullStrings (
                                    (TSV.parse (String data).replace /[\r\n]+$/g, ""))
                            )
                        catch parseError then loaded parseError
                else # when ".csv"
                    parser = csv.parse (_.clone MindbenderUtils.CSV_OPTIONS)
                    output = []
                    parser
                        .on "readable", ->
                            while record = parser.read()
                                output.push record
                        .on "error", loaded
                        .on "finish", ->
                            loaded null, MindbenderUtils.deserializeNullStrings output
                    input = (fs.createReadStream fName)
                        .on "error", loaded
                        .on "open", -> input.pipe parser
        catch err
            loaded err
    @loadOptionalDataFile: (fName, defaultValue, next) ->
        fs.exists fName, (exists) ->
            if exists
                MindbenderUtils.loadDataFile fName, next
            else
                next null, defaultValue
    @writeDataFile: (fName, array, next) ->
        try
            util.log "writing #{fName}"
            switch path.extname fName
                when ".json"
                    fs.writeFile fName, (JSON.stringify array, null, 1), next
                when ".tsv"
                    fs.writeFile fName, (TSV.stringify (
                        MindbenderUtils.serializeNulls (
                            MindbenderUtils.escapeWithBackslashes array))), next
                else # when ".csv"
                    # find out the columns first
                    columns = MindbenderUtils.findAllKeys objs
                    # Stringify all columns
                    arrayProcessed =
                        for row in array
                            rowProcessed = {}
                            rowProcessed[col] = String val for col,val of row
                            rowProcessed
                    arrayProcessed = MindbenderUtils.serializeNulls arrayProcessed
                    # write CSV
                    csv.stringify arrayProcessed, {
                        header: yes
                        columns
                    }, (err, formatted) ->
                        return next err if err
                        fs.writeFile fName, formatted, next
        catch err
            next err

