#!/usr/bin/env bash
# md-to-adf.sh [file]  (reads stdin if no file)
#
# Converts a markdown subset into an Atlassian Document Format (ADF) document so
# Jira renders structured, readable tickets — headings, paragraphs, bullet and
# numbered lists, and code blocks — instead of one flattened wall of text.
#
# This is what makes a Jira ticket a self-contained implementation brief that any
# session, opencode, or other AI tool can pick up and build from Jira alone.
#
# Supported: # … ###### headings · - / * / [ ] bullets · 1. ordered · ``` code
# fences · blank-line-separated paragraphs. Unsupported inline marks degrade to
# plain text (content is never lost).
set -euo pipefail

SRC="${1:-/dev/stdin}"

# 1) Classify each line into TYPE<TAB>TEXT so jq does all JSON escaping safely.
awk '
  BEGIN { incode=0 }
  /^```/        { incode = !incode; print (incode ? "CODE_OPEN" : "CODE_CLOSE") "\t"; next }
  incode        { print "COD\t" $0; next }
  /^[[:space:]]*$/ { print "BLK\t"; next }
  /^#{1,6} /    { n=index($0," "); lvl=n-1; if(lvl>6)lvl=6; print "H" lvl "\t" substr($0,n+1); next }
  /^[[:space:]]*[-*] / { s=$0; sub(/^[[:space:]]*[-*] +/,"",s); sub(/^\[[ xX]\] +/,"",s); print "BUL\t" s; next }
  /^[[:space:]]*[0-9]+\. / { s=$0; sub(/^[[:space:]]*[0-9]+\. +/,"",s); print "ORD\t" s; next }
  { print "PAR\t" $0 }
' "$SRC" |
# 2) Fold the token stream into ADF nodes, grouping consecutive bullets/ordered/
#    code/paragraph lines. jq handles escaping; empty text nodes are dropped.
jq -R -n '
  def txt($s): { type:"text", text:$s };
  def para($lines): { type:"paragraph", content:[ txt(($lines|join(" "))) ] };
  def listOf($kind; $items):
    { type:$kind, content:[ $items[] | { type:"listItem", content:[ para([.]) ] } ] };
  def flush($p):
    if   $p == null then []
    elif $p.k=="par" then [ para($p.v) ]
    elif $p.k=="cod" then [ { type:"codeBlock", content:[ txt(($p.v|join("\n"))) ] } ]
    elif $p.k=="bul" then [ listOf("bulletList";  $p.v) ]
    elif $p.k=="ord" then [ listOf("orderedList"; $p.v) ]
    else [] end;
  reduce (inputs | select(length>0) | { t:(.[0:index("\t")]), x:(.[(index("\t")+1):]) }) as $tok
    ( { out:[], pend:null, incode:false };
      if $tok.t=="CODE_OPEN"  then .incode=true  | .out+=flush(.pend) | .pend={k:"cod",v:[]}
      elif $tok.t=="CODE_CLOSE" then .incode=false | .out+=flush(.pend) | .pend=null
      elif .incode then .pend.v += [$tok.x]
      elif $tok.t=="BLK" then .out+=flush(.pend) | .pend=null
      elif ($tok.t|test("^H[1-6]$")) then
        (.out+=flush(.pend) | .pend=null
         | if ($tok.x|gsub("^\\s+|\\s+$";"")) != "" then
             .out += [ { type:"heading", attrs:{ level:($tok.t[1:2]|tonumber) }, content:[ txt($tok.x) ] } ]
           else . end)
      elif $tok.t=="BUL" then (if .pend.k=="bul" then .pend.v+=[$tok.x] else .out+=flush(.pend) | .pend={k:"bul",v:[$tok.x]} end)
      elif $tok.t=="ORD" then (if .pend.k=="ord" then .pend.v+=[$tok.x] else .out+=flush(.pend) | .pend={k:"ord",v:[$tok.x]} end)
      else (if .pend.k=="par" then .pend.v+=[$tok.x] else .out+=flush(.pend) | .pend={k:"par",v:[$tok.x]} end)
      end
    )
  | (.out + flush(.pend))
  | { type:"doc", version:1, content:( if length==0 then [ { type:"paragraph", content:[ txt(" ") ] } ] else . end ) }
'
