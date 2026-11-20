import sys
from pathlib import Path

# Run from ml/: make `common` and `forecast` importable however pytest was started.
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
