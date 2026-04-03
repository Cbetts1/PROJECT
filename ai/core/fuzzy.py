#!/usr/bin/env python3
"""ai/core/fuzzy.py — fuzzy command-name matcher using difflib.

Usage:
    python3 fuzzy.py --input <typed> --candidates <cmd1,cmd2,...>

Prints the closest match to stdout, or nothing if no match meets the
similarity cutoff.
"""
import argparse
import difflib
from typing import List


def best_match(term: str, candidates: List[str], cutoff: float = 0.6) -> str:
    """Return the best matching candidate, or empty string if none qualify."""
    matches = difflib.get_close_matches(term, candidates, n=1, cutoff=cutoff)
    return matches[0] if matches else ""


def main() -> None:
    parser = argparse.ArgumentParser(description="Fuzzy command-name suggester")
    parser.add_argument("--input",      required=True,  help="The mistyped command")
    parser.add_argument("--candidates", required=True,  help="Comma-separated known commands")
    args = parser.parse_args()

    candidates = [c.strip() for c in args.candidates.split(",") if c.strip()]
    suggestion = best_match(args.input.strip(), candidates)
    if suggestion:
        print(suggestion)


if __name__ == "__main__":
    main()
