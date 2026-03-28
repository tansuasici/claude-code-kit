## Context Gathering

Before analysis, map the project:
1. Read project config (`package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, etc.)
2. Identify the tech stack, frameworks, and key dependencies
3. Map source directories — skip `node_modules`, `vendor`, `build`, `.next`, `dist`, `__pycache__`
4. Check for existing configurations relevant to this analysis (linters, formatters, CI configs)
5. If the user specified a scope, narrow to those files/directories only