# CODEBASE_MAP.md

## What

<!-- One paragraph: what this Django app does and who uses it. -->
A Django [web app / REST API] that [does X for Y].

## Why

<!-- The problem it solves and the core constraints. -->

## Tech Stack

- **Framework**: Django <!-- version --> <!-- + Django REST Framework if API -->
- **Python**: <!-- version, see requirements/pyproject -->
- **Database**: <!-- PostgreSQL (recommended) / MySQL / SQLite -->
- **Async / tasks**: <!-- Celery + Redis/RabbitMQ, or none -->
- **Auth**: Django auth <!-- + DRF tokens / JWT / sessions -->
- **Testing**: <!-- pytest + pytest-django, or manage.py test -->

## Key Commands

| Action | Command |
|--------|---------|
| Run dev server | `python manage.py runserver` |
| System checks | `python manage.py check` |
| Make migrations | `python manage.py makemigrations` |
| Check for missing migrations | `python manage.py makemigrations --check --dry-run` |
| Apply migrations | `python manage.py migrate` |
| Tests | `pytest` (or `python manage.py test`) |
| Lint / format | `ruff check . && black --check .` |
| Shell | `python manage.py shell` |

## Directory Structure

```text
.
├── manage.py           # Django CLI entry point
├── config/             # project package (settings, urls, wsgi/asgi)
│   ├── settings/       # base.py / dev.py / prod.py (or settings.py)
│   ├── urls.py         # root URL conf
│   └── wsgi.py
├── apps/               # your Django apps
│   └── <app>/
│       ├── models.py   # data model (migrations are protected)
│       ├── views.py    # thin views
│       ├── services.py # business logic (fat models / services)
│       ├── serializers.py  # DRF (if API)
│       └── migrations/
├── requirements.txt    # dependencies (protected)
└── pytest.ini / pyproject.toml
```

## Critical Files

| File | Purpose |
|------|---------|
| `config/settings/` | Settings per environment (protected) |
| `config/urls.py` | URL → view routing |
| `apps/<app>/models.py` | Data model — changes require migrations (protected) |
| `requirements.txt` | Dependency set (protected) |
| <!-- add your core apps --> | |

## Architecture

<!-- App boundaries, request flow (URL → view → service → model), where business logic lives. -->

## Known Constraints

<!-- Django/Python version floor, DB engine assumptions, sync vs async, migration policy. -->

## Environment

<!-- Required env vars (SECRET_KEY, DATABASE_URL, ...), secrets management, local setup. -->
