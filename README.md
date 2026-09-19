# Policy-enforced Multi-cloud IaC Pipeline - Infrastructure

## Python tooling setup

Scripts under [tools/](tools/) (e.g. `tools/summarize_plan/summarize_plan.py`) and
their tests need Python 3.12 (see [.tool-versions](.tool-versions)) and pytest.

```bash
# from the repo root
python3.12 -m venv .venv
source .venv/bin/activate

pip install --upgrade pip
pip install -r requirements-python.txt
```

Run a tool's tests, e.g.:

```bash
pytest tools/summarize_plan/ -v
```

Deactivate the venv when done with `deactivate`.