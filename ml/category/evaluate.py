"""Evaluates the category model on SYNTHETIC entries. Every number printed here is
synthetic, never real-world performance.

- Split by merchant TEMPLATE: leave one template out, train on the rest, score the
  held-out template's rows. A merchant's spellings never appear on both sides.
- Baselines on the same split: the majority class of the training fold, and a keyword
  baseline that maps each word seen in training to its most common category.
- Confidence: accuracy and coverage of the top answer at several thresholds.
- Learning curve: a simulated person with some unrelated history labels the first k
  entries of the held-out merchant, and the blend is scored on that merchant's later entries.
  Curve A keeps the true category; curve B moves the merchant to a category of the person's
  own that the model has never seen.

Run from ml/:  python -m category.evaluate
"""

from __future__ import annotations

import random
from collections import Counter, defaultdict

import numpy as np

from common.synth import EVERYDAY

from .features import normalise
from .personal import PersonalLayer, blend
from .train import SEED, category_rows, fit, predict_proba

KS = (0, 1, 3, 5, 10)
THRESHOLDS = (0.5, 0.6, 0.7, 0.8, 0.9)
BACKGROUND = 40
OWN_CATEGORY = "cat.custom.own"

_SPELLINGS = {t.template_id: set(t.descriptions) for t in EVERYDAY}


def _words(description: str) -> list[str]:
    return normalise(description).split()


def keyword_fit(rows: list[dict]):
    votes: dict[str, Counter] = defaultdict(Counter)
    for r in rows:
        for w in set(_words(r["description"])):
            votes[w][r["category_id"]] += 1
    majority = Counter(r["category_id"] for r in rows).most_common(1)[0][0]
    return {w: c.most_common(1)[0][0] for w, c in votes.items()}, majority


def keyword_predict(model, description: str) -> str:
    table, majority = model
    hits = Counter(table[w] for w in _words(description) if w in table)
    return hits.most_common(1)[0][0] if hits else majority


def run(seed: int = SEED) -> dict:
    rows = category_rows(seed)
    templates = sorted({r["template"] for r in rows})
    rng = random.Random(seed)
    res = {"rows": len(rows), "templates": len(templates), "per_template": {}}
    y_true, y_model, p_model, y_major, y_key, is_typo = [], [], [], [], [], []
    curve_a = {k: [0, 0] for k in KS}
    curve_b = {k: [0, 0] for k in KS}
    blended_pairs: list[tuple[float, bool]] = []
    for t in templates:
        train = [r for r in rows if r["template"] != t]
        test = [r for r in rows if r["template"] == t]
        vec, clf = fit(train)
        probs = predict_proba(vec, clf, [r["description"] for r in test], [r["amount"] for r in test], [r["hour"] for r in test])
        classes = list(clf.classes_)
        kw = keyword_fit(train)
        majority = kw[1]
        correct = 0
        for r, p in zip(test, probs):
            top = classes[int(np.argmax(p))]
            y_true.append(r["category_id"])
            y_model.append(top)
            p_model.append(float(p.max()))
            y_major.append(majority)
            y_key.append(keyword_predict(kw, r["description"]))
            is_typo.append(t in _SPELLINGS and r["description"] not in _SPELLINGS[t])
            correct += top == r["category_id"]
        res["per_template"][t] = (correct / len(test), len(test))

        # Learning curve on this held-out merchant.
        background = rng.sample(train, BACKGROUND)
        model_probs = [dict(zip(classes, map(float, p))) for p in probs]
        for k in KS:
            if len(test) <= k:
                continue
            for curve, relabel in ((curve_a, None), (curve_b, OWN_CATEGORY)):
                layer = PersonalLayer()
                for r in background:
                    layer.add(r["description"], r["category_id"])
                for r in test[:k]:
                    layer.add(r["description"], relabel or r["category_id"])
                for r, mp in zip(test[k:], model_probs[k:]):
                    p = blend(mp, layer, r["description"])
                    truth = relabel or r["category_id"]
                    top = max(p, key=p.get)
                    curve[k][0] += top == truth
                    curve[k][1] += 1
                    if relabel is None and k > 0:
                        blended_pairs.append((p[top], top == truth))

    y_true = np.array(y_true)
    acc = lambda pred: float(np.mean(np.array(pred) == y_true))  # noqa: E731
    res["model"] = acc(y_model)
    res["majority"] = acc(y_major)
    res["keyword"] = acc(y_key)
    res["macro_template"] = float(np.mean([a for a, _ in res["per_template"].values()]))
    typo = np.array(is_typo)
    res["typo_rows"] = int(typo.sum())
    res["model_typo"] = float(np.mean(np.array(y_model)[typo] == y_true[typo]))
    res["keyword_typo"] = float(np.mean(np.array(y_key)[typo] == y_true[typo]))
    p_model = np.array(p_model)
    hit = np.array(y_model) == y_true
    res["thresholds"] = {
        th: (float(hit[p_model >= th].mean()) if (p_model >= th).any() else float("nan"), float((p_model >= th).mean()))
        for th in THRESHOLDS
    }
    bp = np.array([p for p, _ in blended_pairs])
    bh = np.array([h for _, h in blended_pairs])
    res["blended_thresholds"] = {
        th: (float(bh[bp >= th].mean()) if (bp >= th).any() else float("nan"), float((bp >= th).mean()))
        for th in THRESHOLDS
    }
    counts = Counter(y_true.tolist())
    res["largest_class"] = counts.most_common(1)[0][1] / len(y_true)
    res["curve_a"] = {k: c / n for k, (c, n) in curve_a.items() if n}
    res["curve_b"] = {k: c / n for k, (c, n) in curve_b.items() if n}
    return res


def main() -> None:
    r = run()
    print(f"SYNTHETIC data: {r['rows']} rows, {r['templates']} merchant templates, leave-one-template-out")
    print(f"  model accuracy (rows)      {r['model']:.3f}")
    print(f"  model accuracy (templates) {r['macro_template']:.3f}")
    print(f"  majority-class baseline    {r['majority']:.3f} (majority of each training fold)")
    print(f"  largest class share        {r['largest_class']:.3f} (one class for every row)")
    print(f"  keyword baseline           {r['keyword']:.3f}")
    print(f"  typo rows {r['typo_rows']}: model {r['model_typo']:.3f}, keyword {r['keyword_typo']:.3f}")
    print("  threshold: accuracy when shown, share shown")
    for th, (a, cov) in r["thresholds"].items():
        print(f"    >= {th:.1f}: {a:.3f}, {cov:.3f}")
    print("  blended, after 1 to 10 labelled entries: accuracy when shown, share shown")
    for th, (a, cov) in r["blended_thresholds"].items():
        print(f"    >= {th:.1f}: {a:.3f}, {cov:.3f}")
    print("  learning curve, accuracy after k labelled entries of the held-out merchant")
    for k in KS:
        print(f"    k={k:>2}: same category {r['curve_a'].get(k, float('nan')):.3f}, own new category {r['curve_b'].get(k, float('nan')):.3f}")
    print("  per template (accuracy, rows)")
    for t, (a, n) in sorted(r["per_template"].items()):
        print(f"    {t:<22} {a:.3f} {n}")


if __name__ == "__main__":
    main()
