import sys
import textwrap

def main():
    wrapper = textwrap.TextWrapper(
        width=100,
        break_long_words=False,     # Prevent splitting of whole words
        replace_whitespace=False,   # Preserve original spacing (including tabs)
        drop_whitespace=True,      # Preserve leading/trailing whitespace
        break_on_hyphens=False      # Avoid splitting hyphenated words (optional, improves layout)
    )

    for line in sys.stdin:
        stripped_line = line.rstrip('\n')

        if not stripped_line:       # Preserve empty lines (used for paragraph breaks)
            print()
            continue

        wrapped_lines = wrapper.wrap(stripped_line)

        for wrapped_line in wrapped_lines:
            print(wrapped_line)

if __name__ == "__main__":
    main()