#!/usr/bin/env python3
import time
from pathlib import Path

from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC


def main() -> None:
    url = "https://www.chessgames.com/"
    output_path = Path("./results.html")

    options = webdriver.ChromeOptions()
    options.add_argument("--headless=new")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-gpu")
    options.add_argument("--window-size=1280,800")

    driver = webdriver.Chrome(options=options)
    try:
        driver.get(url)

        wait = WebDriverWait(driver, 15)

        search_box = wait.until(
            EC.presence_of_element_located((By.NAME, "q"))
        )
        search_box.clear()
        search_box.send_keys("morphy")
        search_box.send_keys(Keys.RETURN)

        # Wait for results page to load by checking URL change or results form
        wait.until(lambda d: "search" in d.current_url.lower())

        # Small delay to allow dynamic content to settle, if any
        time.sleep(1)

        output_path.write_text(driver.page_source, encoding="utf-8")
        print(f"Saved results to {output_path.resolve()}")
    finally:
        driver.quit()


if __name__ == "__main__":
    main()
