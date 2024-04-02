INPUT=$1
OUTPUT=$2
TMP=$OUTPUT.tmp

echo "INPUT: $INPUT"
echo "OUTPUT: $OUTPUT"

### Preprocess


# Replace all occurances of <xterm> with <code bash>
sed 's/<xterm>/<code bash>/g' $INPUT > $TMP
# Replace all occurances of </xterm> with </code>
sed -i 's/<\/xterm>/<\/code>/g' $TMP

### Pandoc
# Make JSON
pandoc -L adi_wiki.lua --verbose -f dokuwiki -t json -o $OUTPUT.json $TMP
# Make Markdown
pandoc -L adi_wiki.lua --verbose -f dokuwiki -t markdown-pipe_tables-simple_tables-multiline_tables-grid_tables -o $OUTPUT.md $TMP


### Postprocess
# pip install mdformat-myst
mdformat $OUTPUT.md