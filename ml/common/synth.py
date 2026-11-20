"""Seeded SYNTHETIC generator of Ugandan-style money entries.

Every row this module makes is synthetic. The merchant names, amounts and habits are
invented to resemble everyday Kampala spending; they are not drawn from any real person's
records and must never be reported as real-world performance.

Output columns (CSV):
  description   free text, as a person might type it (may include typos, Luganda, English)
  amount        whole shillings (UGX)
  category_id   one of the app's default category ids (cat.food, cat.transport, ...)
  hour          0-23 local (Africa/Kampala) hour of the entry
  day           integer day index from the start of the series
  template      merchant template id; used to split train and test by merchant, never by row
  series_id     regular-payment series this row belongs to ("" when none)
  is_regular    1 when the row is an occurrence of a regular payment
  is_anomaly    1 when the row was injected as an unusual payment (for evaluation only)
  synthetic     always 1
"""

from __future__ import annotations

import csv
import random
from dataclasses import dataclass
from pathlib import Path

# The app's default category ids (app/lib/data/seed/default_data.dart).
FOOD = "cat.food"
TRANSPORT = "cat.transport"
BILLS = "cat.bills"
SCHOOL = "cat.school"
FAMILY = "cat.family"
HEALTH = "cat.health"
OTHER = "cat.other"


@dataclass(frozen=True)
class Template:
    template_id: str
    category: str
    descriptions: tuple[str, ...]  # spellings a person might type, incl. typos
    median_amount: int  # shillings
    spread: float  # log-normal sigma for the amount
    hours: tuple[int, ...]  # the hours this merchant is usually used at


# Everyday templates. Descriptions mix English, Luganda and common typos on purpose.
EVERYDAY: tuple[Template, ...] = (
    Template("food_market", FOOD, ("Nakasero market", "nakasero mkt", "Kalerwe market veg", "market vegetables", "matooke"), 15000, 0.45, (8, 9, 10, 17, 18)),
    Template("food_posho", FOOD, ("posho and beans", "posho beans lunch", "emmere", "lunch posho", "pozho"), 5000, 0.35, (12, 13)),
    Template("food_shop", FOOD, ("Quality Supermarket", "Capital shoppers", "groceries", "grocries", "shop sugar and soap"), 42000, 0.5, (17, 18, 19, 20)),
    Template("food_cafe", FOOD, ("Java House", "coffee and sandwich", "Cafe Javas", "snack", "Kikuubo chips"), 9000, 0.4, (10, 11, 15, 16)),
    Template("transport_boda", TRANSPORT, ("boda to work", "boda boda", "bodaboda home", "boda kikuubo", "taxi to town"), 4000, 0.3, (7, 8, 17, 18, 19)),
    Template("transport_taxi", TRANSPORT, ("Safe boda ride", "taxi Kisenyi", "matatu to Ntinda", "matatu", "taxi fare"), 2500, 0.25, (7, 8, 17)),
    Template("transport_fuel", TRANSPORT, ("Shell fuel", "Total petrol", "fuel 20k", "petrol for car", "Vivo energy"), 60000, 0.3, (9, 10, 18)),
    Template("bills_airtime", BILLS, ("MTN airtime", "airtel credit", "MTN bundles", "data bundle", "airtme top up"), 5000, 0.5, (8, 12, 20, 21)),
    Template("bills_umeme", BILLS, ("Umeme prepaid", "umeme token", "yaka electricity", "electricity units"), 30000, 0.4, (9, 10, 11)),
    Template("bills_water", BILLS, ("NWSC water", "National Water bill", "water bill"), 20000, 0.3, (10, 11)),
    Template("bills_internet", BILLS, ("Smile internet", "Wi-Fi bundle", "fibre bill", "internet monthly"), 80000, 0.2, (9, 10)),
    Template("school_fees", SCHOOL, ("school fees term", "Kampala Parents school", "school fees", "skul fees", "scool fees"), 250000, 0.4, (9, 10, 11)),
    Template("school_stationery", SCHOOL, ("books and pens", "stationery shop", "exercise books", "uniform"), 18000, 0.5, (14, 15)),
    Template("family_gift", FAMILY, ("send to mum", "MoMo to mother", "family support", "Mama upkeep", "gift for aunt"), 100000, 0.6, (8, 9, 19)),
    Template("health_pharmacy", HEALTH, ("pharmacy", "Pharmaceutical drugs", "paracetamol", "clinic visit", "chemist"), 12000, 0.5, (9, 16, 17)),
    Template("other_misc", OTHER, ("airtime shop", "phone case", "hair salon", "barber", "soap and tissue", "charity"), 10000, 0.7, (11, 12, 13, 14, 15, 16)),
)


@dataclass(frozen=True)
class RegularSeries:
    series_id: str
    description: str
    category: str
    amount: int
    every_days: int  # 30 monthly, 7 weekly
    skip_rate: float  # chance an occurrence is missing
    hour: int


REGULAR: tuple[RegularSeries, ...] = (
    RegularSeries("rent", "house rent", BILLS, 600000, 30, 0.05, 9),
    RegularSeries("school_term", "school fees term 2", SCHOOL, 250000, 90, 0.0, 10),
    RegularSeries("gym", "Kampala gym monthly", HEALTH, 80000, 30, 0.1, 7),
    RegularSeries("dstv", "DStv subscription", BILLS, 45000, 30, 0.05, 20),
    RegularSeries("netflix", "Netflix", OTHER, 35000, 30, 0.05, 2),
    RegularSeries("insurance", "Jubilee insurance", HEALTH, 120000, 30, 0.0, 9),
)


def _amount(rng: random.Random, t: Template) -> int:
    value = t.median_amount * rng.lognormvariate(0.0, t.spread)
    return max(500, int(round(value / 100.0)) * 100)


def _typo(rng: random.Random, text: str) -> str:
    if len(text) < 4 or rng.random() > 0.15:
        return text
    i = rng.randrange(1, len(text) - 1)
    return text[:i] + text[i + 1] + text[i] + text[i + 2 :]  # swap two letters


def generate_everyday(seed: int, days: int, rows_per_day: float = 2.5) -> list[dict]:
    """Everyday spending over [days] days. Deterministic for a given seed."""
    rng = random.Random(seed)
    out: list[dict] = []
    for day in range(days):
        n = max(0, int(rng.gauss(rows_per_day, 1.0)))
        for _ in range(n):
            t = rng.choice(EVERYDAY)
            out.append(
                {
                    "description": _typo(rng, rng.choice(t.descriptions)),
                    "amount": _amount(rng, t),
                    "category_id": t.category,
                    "hour": rng.choice(t.hours),
                    "day": day,
                    "template": t.template_id,
                    "series_id": "",
                    "is_regular": 0,
                    "is_anomaly": 0,
                    "synthetic": 1,
                }
            )
    return out


def generate_regular(seed: int, days: int) -> list[dict]:
    """Occurrences of the regular payments, with missed months and small jitter."""
    rng = random.Random(seed + 1)
    out: list[dict] = []
    for s in REGULAR:
        day = rng.randrange(0, s.every_days)
        while day < days:
            if rng.random() >= s.skip_rate:
                jitter = rng.randint(-2, 2)
                out.append(
                    {
                        "description": s.description,
                        "amount": s.amount + rng.randint(-2, 2) * 100,
                        "category_id": s.category,
                        "hour": s.hour,
                        "day": min(days - 1, max(0, day + jitter)),
                        "template": f"regular_{s.series_id}",
                        "series_id": s.series_id,
                        "is_regular": 1,
                        "is_anomaly": 0,
                        "synthetic": 1,
                    }
                )
            day += s.every_days
    return out


def inject_anomalies(seed: int, rows: list[dict], rate: float = 0.02) -> list[dict]:
    """Adds unusual entries: a much larger amount, or an odd hour, or a new payee."""
    rng = random.Random(seed + 2)
    extra: list[dict] = []
    days = max(r["day"] for r in rows) + 1
    for _ in range(int(len(rows) * rate)):
        base = rng.choice(EVERYDAY)
        kind = rng.choice(("amount", "hour", "payee"))
        amount = _amount(rng, base)
        hour = rng.choice(base.hours)
        description = rng.choice(base.descriptions)
        if kind == "amount":
            amount *= rng.choice((8, 12, 20))
        elif kind == "hour":
            hour = rng.choice((1, 2, 3, 4))
        else:
            description = f"new payee {rng.randrange(1000, 9999)}"
        extra.append(
            {
                "description": description,
                "amount": amount,
                "category_id": base.category,
                "hour": hour,
                "day": rng.randrange(days),
                "template": f"anomaly_{kind}",
                "series_id": "",
                "is_regular": 0,
                "is_anomaly": 1,
                "synthetic": 1,
            }
        )
    return rows + extra


def write_csv(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def make_dataset(seed: int = 7, days: int = 540) -> list[dict]:
    """Everyday spending, regular payments and injected anomalies, sorted by day."""
    rows = generate_everyday(seed, days) + generate_regular(seed, days)
    rows = inject_anomalies(seed, rows)
    rows.sort(key=lambda r: (r["day"], r["hour"], r["description"]))
    return rows


if __name__ == "__main__":
    here = Path(__file__).resolve().parent.parent
    data = make_dataset()
    write_csv(here / "data" / "synthetic_entries.csv", data)
    print(f"wrote {len(data)} synthetic rows")
