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
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-blink-features=AutomationControlled")
    options.add_experimental_option("excludeSwitches", ["enable-automation"])
    options.add_experimental_option("useAutomationExtension", False)
    options.add_argument(
        "--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    )

    driver = webdriver.Chrome(options=options)
    try:
        # Reduce obvious webdriver fingerprints
        driver.execute_cdp_cmd(
            "Page.addScriptToEvaluateOnNewDocument",
            {
                "source": """
                    Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
                """
            },
        )

        driver.get(url)

        wait = WebDriverWait(driver, 15)

        print("Waiting for input[name='search'] to be present...")
        search_box = wait.until(
            EC.presence_of_element_located((By.NAME, "search"))
        )
        search_box.clear()
        search_box.send_keys("morphy")
        search_box.send_keys(Keys.RETURN)

        # Wait for results page to load by checking URL change or results form
        print("Waiting for results page URL to include 'search'...")
        wait.until(lambda d: "search" in d.current_url.lower())

        # Small delay to allow dynamic content to settle, if any
        time.sleep(1)

        output_path.write_text(driver.page_source, encoding="utf-8")
        print(f"Saved results to {output_path.resolve()}")
    finally:
        driver.quit()


if __name__ == "__main__":
    main()
