# named parameters given
export table='sentences_escort'

: ${table:?name of the table that contains all sentences} # required
: ${document_id_column:=doc_id}  # name of the column that contains the document identifier of each sentence
export table document_id_column
