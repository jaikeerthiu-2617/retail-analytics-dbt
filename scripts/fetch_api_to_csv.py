"""Fetch FakeStore product data and save it as a dbt seed CSV."""

from pathlib import Path

import pandas as pd
import requests


API_URL = "https://fakestoreapi.com/products"
PROJECT_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_PATH = PROJECT_ROOT / "dbt" / "seeds" / "products.csv"


def fetch_products() -> list[dict]:
    """Fetch product records from FakeStore."""
    response = requests.get(API_URL, timeout=30)
    response.raise_for_status()
    return response.json()


def flatten_products(products: list[dict]) -> pd.DataFrame:
    """Flatten the nested rating object into seed-friendly columns."""
    rows = []
    for product in products:
        rating = product.get("rating") or {}
        rows.append(
            {
                "product_id": product.get("id"),
                "title": product.get("title"),
                "price": product.get("price"),
                "category": product.get("category"),
                "description": product.get("description"),
                "rating_rate": rating.get("rate"),
                "rating_count": rating.get("count"),
            }
        )
    return pd.DataFrame(rows)


def main() -> None:
    """Fetch, flatten, and write the product seed CSV."""
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    df = flatten_products(fetch_products())
    df.to_csv(OUTPUT_PATH, index=False)
    print(f"Wrote {len(df)} products to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
