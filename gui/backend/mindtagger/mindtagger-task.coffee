fs = require "fs"
path = require "path"
util = require "util"
async = require "async"
_ = require "underscore"

{MindbenderUtils} = require "../mindbender-utils"

## A Mindtagger task that holds items and tags with a schema and other info
exports.MindtaggerTask =
class MindtaggerTask
    @ALL = {}
    @nameFor: (taskName, params) ->
        if params?
            for name in (_.keys params).sort()
                value = params[name]
                taskName += " #{name}=#{value}"
        taskName

    constructor: (@config, @params, next) ->
        # load task config if necessary
        unless typeof @config is "object"
            configFile = @config
            @config = JSON.parse (fs.readFileSync configFile)
            @config.file = configFile
            @config.path = path.resolve (path.dirname configFile)
        throw new Error "No path set in config", @config unless @config.path
        # determine task's name
        @config.name ?= path.basename @config.path
        @config.name = MindtaggerTask.nameFor @config.name, @params
        if MindtaggerTask.ALL[@config.name]?
            suffix = 1
            ++suffix while MindtaggerTask.ALL["#{@config.name}-#{suffix}"]?
            @config.name += "-#{suffix}"
        # do not actually load anything if this is a parameterized task but no values were supplied
        if @config.params?.length > 0 and not @params?
            @isAbstract = -> yes
            @instantiateIfNeeded = (params, next) =>
                instanceName = MindtaggerTask.nameFor @config.name, params
                instance = MindtaggerTask.ALL[instanceName]
                if instance?
                    next null, instance, instanceName
                else
                    # instantiate one if doesn't exist yet
                    config = _.extend {}, @config
                    new MindtaggerTask config, params, (err, instance) =>
                        instance.baseTask = @
                        next null, instance, instanceName
            MindtaggerTask.registerTask @
            next null, @
        else
            @isAbstract = -> no
            # expand all parameters
            @config = MindbenderUtils.expandParameters @config, @params
            # making sure there's tags config as it's crucial
            @config.tags ?=
                storage: "file"
                file: "tags.json"
            # initialize fields
            @allItems = null
            @allTags = null
            @areTagsDirty = no
            # load all schema files and merge
            @baseTagsSchema = {}
            schemaFiles = ("#{dir}/schema.json" for dir in [@config.path])
            async.map schemaFiles,
                (fName, next) -> MindbenderUtils.loadOptionalDataFile fName, {}, next
            , (err, schemas) =>
                return next err if err
                _.extend @baseTagsSchema, s for s in schemas.reverse()
                # finally, register itself
                MindtaggerTask.registerTask @
                next null, @

    preferCached: (cache, generator) -> (next) ->
        if cache?
            next null, cache
        else
            generator next

    createEmptyTags: =>
        version: 1
        key_columns: @config.items?.key_columns ? []
        by_key: {}

    getAllItemsAndTags: (next) =>
        async.parallel {
            allItems: @preferCached @allItems, (next) =>
                itemsFile = path.resolve @config.path, @config.items?.file
                MindbenderUtils.loadDataFile itemsFile, (err, @allItems) =>
                    return next err if err
                    @allItems ?= []
                    next err, @allItems
            allTags: @preferCached @allTags, (next) =>
                tagsFile = path.resolve @config.path, @config.tags.file
                emptyTags = @createEmptyTags()
                MindbenderUtils.loadOptionalDataFile tagsFile, emptyTags, (err, @allTags) =>
                    return next err if err
                    @allTags ?= emptyTags
                    next err, @allTags
        }, (err, {allItems, allTags}) =>
            return next err, {} if err
            # XXX backward compatibility: upgrade Array-type tags to Object
            if allTags instanceof Array
                util.log "#{@config.name}: upgrading #{@config.tags.file} from Array"
                tagsArray = allTags
                allTags = @allTags = @createEmptyTags()
                for tag,idx in tagsArray when tag?
                    key = @keyFor allItems[idx], idx
                    allTags.by_key[key] = tag
            # XXX backward compatibility: upgrade plain Object tags
            unless allTags.version? and allTags.by_key? and "object" is typeof allTags.by_key
                util.log "#{@config.name}: upgrading #{@config.tags.file} from plain Object"
                byKey = allTags
                allTags = @allTags = @createEmptyTags()
                allTags.by_key = byKey
            # make sure we know how to handle this version
            unless allTags.version == 1
                err = new Error "#{@config.tags.file} version #{allTags.version} unsupported"
                util.log err
                return next err, {}
            # try upgrading if key_columns have changed
            if (JSON.stringify allTags.key_columns) isnt (JSON.stringify @config.items?.key_columns)
                util.log "#{@config.name}: upgrading keys for #{@config.tags.file} from [#{allTags.key_columns}] to [#{@config.items?.key_columns}]"
                byNewKey = {}
                oldKeyColumns = allTags.key_columns
                for item,idx in allItems
                    oldKey = @keyFor item, idx, oldKeyColumns
                    if (tag = allTags.by_key[oldKey])?
                        newKey = @keyFor item, idx
                        byNewKey[newKey] = tag
                        delete allTags.by_key[oldKey]
                        break if (_.size allTags.by_key) == 0
                allTags.by_key = byNewKey
                allTags.key_columns = @config.items?.key_columns
            next null, {allItems, allTags}

    getItemsWithTags: (next, group, offset, limit) =>
        @getAllItemsAndTags (err, {allItems, allTags}) =>
            return next err, {} if err
            # filter to the group if necessary when grouping_columns exist
            if group and @config.items?.grouping_columns
                util.log "#{@config.name}: grouping items with [#{@config.items?.grouping_columns}]"
                groupedItems = @groupItems allItems
                groups = _.keys groupedItems
                groupIdx = groups.indexOf group
                allItems = groupedItems[group] ? []
                grouping =
                    filter  : group
                    previous: groups[groupIdx - 1]
                    next    : groups[groupIdx + 1]
            else
                grouping = null
            # offset, limit
            # TODO more sanity check offset, limit
            util.log "#{@config.name}: selecting items with offset=#{offset} limit=#{limit}"
            items =
                if offset? and limit?
                    allItems[offset...(offset+limit)]
                else if offset?
                    allItems[offset...]
                else if limit?
                    allItems[...limit]
                else
                    allItems
            # join items with tags
            util.log "#{@config.name}: joining #{items.length} items with their tags"
            tags = []
            for item,i in items
                idx = offset + i
                key = @keyFor item, idx
                tags.push allTags.by_key[key]
            next null, {
                grouping
                itemsCount: allItems.length
                items
                tags
            }

    keyFor: (item, idx, key_columns = @config.items?.key_columns) =>
        if key_columns?.length > 0
            # use the configured key_columns
            (item[k] for k in key_columns).join "\t"
        else
            # or simply the row position
            idx

    groupFor: (item, grouping_columns = @config.items?.grouping_columns) =>
        if grouping_columns?.length > 0
            (item[c] for c in grouping_columns).join "\t"

    groupItems: (allItems) =>
        unless @groupedItems?
            @groupedItems = {}
            for item in allItems
                (@groupedItems[@groupFor item] ?= []).push item
        @groupedItems

    getSchema: (next) => (@preferCached @schema, (next) =>
            @getAllItemsAndTags (err, {allItems, allTags}) =>
                return next err if err
                @schema =
                    items: @config.items?.schema ? @deriveSchema allItems, approximate:yes
                    itemKeys: @config.items?.key_columns
                    tags: @deriveSchema (_.values allTags.by_key), baseSchema: @baseTagsSchema
                next null, @schema
        ) next
    deriveSchema: (tags, {baseSchema, oldTags, approximate}) =>
        util.log "#{@config.name}: deriving schema for #{tags.length} items or tags#{
            if approximate then " approximately" else ""}"
        schema = {}
        _.extend schema, baseSchema if baseSchema?
        if approximate and not oldTags?
            # approximate by sampling if input are too many
            tagsSampled = _.sample tags, (Math.min 100, tags.length)
            invSampleRatio = tags.length / tagsSampled.length  # XXX this naively assumes uniform distribution of tags
            for tag in tagsSampled when tag?
                for name,value of tag when value?
                    v = JSON.stringify value
                    ((schema[name] ?= {}).frequency ?= {})[v] ?= 0
                    schema[name].frequency[v] += invSampleRatio
            for name,s of schema
                s.count = 0
                s.count += f for v,f of s.frequency
        else
            # compute frequency of all values of all tags
            for tag in tags when tag?
                for name,value of tag when value?
                    v = JSON.stringify value
                    ((schema[name] ?= {}).frequency ?= {})[v] ?= 0
                    schema[name].frequency[v] += 1
            # sum the individual frequencies for total count
            for name,s of schema
                s.count = 0 unless oldTags?
                s.count += f for v,f of s.frequency
            if oldTags?
                # perform incremental maintenance of value frequencies if previous
                # values of the same tags were given as well
                for tag in oldTags when tag?
                    for name,value of tag when value? and schema[name]?
                        v = JSON.stringify value
                        unless (schema[name].frequency?[v] -= 1) > 0
                            delete schema[name].frequency[v]
                for name,s of schema
                    s.count -= f for v,f of s.frequency
                    delete s.count unless s.count >= 0
        # infer type by induction on observed values
        for tagName,tagSchema of schema when not tagSchema.type?
            values = (JSON.parse v for v of tagSchema.frequency)
            values.push null
            tagSchema.type =
                if (values.every (v) -> not v? or (typeof v) is 'boolean') or
                        values.length == 2 and
                        not values[0] is not not values[1]
                    tagSchema.values = values
                    'simple'
                else
                    # TODO 'categorical'
                    delete tagSchema.frequency
                    'text'
        schema

    setTagsForItems: (updates, next) =>
        @getAllItemsAndTags (err, {allItems, allTags}) =>
            oldTags = (@allTags.by_key[update.key] for update in updates)
            newTags =
                for update in updates
                    key = update.key
                    @areTagsDirty = yes
                    @allTags.by_key[key] = update.tag
            # update tags schema
            @getSchema (err, schema) =>
                return next err if err
                schema.tags = @deriveSchema newTags, baseSchema: schema.tags, oldTags: oldTags
                next null


    writeChanges: (next) =>
        # write the tags to file
        tagsFile = path.resolve @config.path, @config.tags.file
        write = (next) =>
            MindbenderUtils.writeDataFile tagsFile, @allTags, (err) =>
                @areTagsDirty = no unless err
                next err
        # TODO persist schema as well
        if @areTagsDirty
            write next
        else
            fs.exists tagsFile, (exists) ->
                unless exists
                    write next
                else
                    next null

    @WRITER_T = null
    @WRITER_INTERVAL = 30 * 1000
    @registerTask: (task) ->
        util.log "Loaded Mindtagger task #{task.config.name}"
        MindtaggerTask.ALL[task.config.name] = task
        unless @WRITER_T?
            # set up a periodic task that writes back changes
            @WRITER_T =
                setInterval MindtaggerTask.writeBackChanges, @WRITER_INTERVAL
            # as well as upon receiving signals and exit
            process.on "SIGQUIT", => MindtaggerTask.writeBackChanges()
            process.on "SIGINT",  => MindtaggerTask.writeBackChanges -> process.exit 130
            process.on "SIGTERM", => MindtaggerTask.writeBackChanges -> process.exit 143
            #process.on "exit",    => MindtaggerTask.writeBackChanges -> process.exit 0
    @writeBackChanges: (next = (err) ->) ->
        allConcreteTasks = (task for task in _.values MindtaggerTask.ALL when not task.isAbstract())
        async.each allConcreteTasks, ((task, next) -> task.writeChanges next), next
