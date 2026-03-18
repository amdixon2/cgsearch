#!/usr/bin/python3

import sys
from pathlib import Path
import requests
import browser_cookie3
import os

def main() -> None:
    if len(sys.argv) != 2 or not sys.argv[1].strip():
        print("Usage: ./fetch_page.py <url>")
        sys.exit(1)

    url = sys.argv[1].strip()
    output_path = Path("./response.html")

    # Load cookies from Chrome
    cj = browser_cookie3.chrome()
    # Use cookies in a request
    r = requests.get(url, cookies=cj)

    output_path.write_text(r.text, encoding="utf-8")
    
if __name__ == "__main__":
    main()

