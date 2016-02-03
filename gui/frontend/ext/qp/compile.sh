#!/usr/bin/env bash

pegjs lucene-query.grammar

cat <<-EOF > lucene-query.js
  $(echo "if (typeof define !== 'function') { var define = require('amdefine')(module) };

define([], function() {
var module = {};")
  $(cat lucene-query.js)
  $(echo "return module.exports;
});")
EOF
