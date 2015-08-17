describe "mindbender.mindtagger.arrayParsers module", ->
    beforeEach module "mindbender.mindtagger.arrayParsers"

    describe "parsedPostgresArray filter", ->
        parsedPostgresArrayFilter = null
        beforeEach inject (_parsedPostgresArrayFilter_) ->
            parsedPostgresArrayFilter = _parsedPostgresArrayFilter_

        it "should parse simple arrays correctly", ->
            expect (parsedPostgresArrayFilter """
                    {The,chemotactic,receptor,for,human,C5a,anaphylatoxin,.}
                    """)
                .toEqual [
                    "The"
                    "chemotactic"
                    "receptor"
                    "for"
                    "human"
                    "C5a"
                    "anaphylatoxin"
                    "."
                ]

        it "should parse commas escaped with surrounding quotes correctly", ->
            expect (parsedPostgresArrayFilter """
                    {AF042089,),localized,to,3p13,",",with,the,complete,MYLK,sequence,.}
                    """)
                .toEqual [
                    "AF042089"
                    ")"
                    "localized"
                    "to"
                    "3p13"
                    ","
                    "with"
                    "the"
                    "complete"
                    "MYLK"
                    "sequence"
                    "."
                ]

        it "should parse escaped quotes correctly", ->
            expect (parsedPostgresArrayFilter """
                    {foo,",",bar,"\\"",qux}
                    """)
                .toEqual [
                    "foo"
                    ","
                    "bar"
                    '"'
                    "qux"
                ]

        it "should parse non-quote escapes correctly", ->
            expect (parsedPostgresArrayFilter """
                    {"\\\\ / Vhile ...","YY1 is required ..."}
                    """)
                .toEqual [
                    "\\ / Vhile ..."
                    "YY1 is required ..."
                ]

        it "should parse non-quote escapes correctly", ->
            expect (parsedPostgresArrayFilter """
                    {foo,"\\\\",bar,",",qux}
                    """)
                .toEqual [
                    "foo"
                    "\\"
                    "bar"
                    ","
                    "qux"
                ]
