import sys
import re

def handle_wrap_braces(text):
    # Find all WRAP tags
    # Examples:
    # <WRAP left tip round box 100%>
    all_start_tags = re.findall(r'<WRAP.*?>', text)
    all_end_tags = re.findall(r'</WRAP>', text)
    # organize pairs of start and end tags
    pairs = {}
    tokens = text.split("WRAP>")
    available_starts = []
    available_ends = []
    for i, token in enumerate(tokens):
        if token.startswith("<WRAP"):
            available_starts.append(i)
        if token.startswith("</WRAP"):
            available_ends.append(i)

def run_all_processors(text):
    text = handle_wrap_braces(text)


if __name__ == "__main__":

    in_filename = sys.argv[1]
    out_filename = sys.argv[2]
    with open(in_filename, "r") as f:
        text = f.read()

    text = run_all_processors(text)

    with open(out_filename, "w") as f:
        f.write(text)