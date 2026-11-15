# MIT 8103 - Advanced Database Systems Portfolio
**Case study:** Campus Register, a simulated university registration system.
**Prepared for review by:** Chiamaka Ozurumba. Add your verified matriculation number and repository URL to the summary before submitting.

## Reproduce the practical evidence
Use Python 3.10 or later. No third-party packages, paid services or database server are needed.
1. Download/extract the repository to a disposable local folder.
2. Open a terminal in that folder.
3. Run `python run_portfolio.py` (or `python3 run_portfolio.py`).
4. Read evidence/verification-summary.txt and the other evidence files.
The runner replaces only the generated databases and evidence files within this folder. Save any prior run you want to retain first. It can take a few minutes because inserting the initial dataset includes capacity checks.

## Portfolio map
- portfolio-1-database-design/: scenario, normalisation, schema and ER diagram.
- portfolio-2-query-optimisation/: SQL and benchmark explanation.
- portfolio-3-transactions-concurrency/: transaction outline and interpretation.
- portfolio-4-nosql/: disk-backed key-value model and example record.
- portfolio-5-distributed-cloud/: proposed architecture; not a cloud deployment.
- evidence/: actual outputs from the automated execution, timing samples and assertions.
- generated/: SQLite and key-value databases produced by that execution.

## Verification and authorship
These files were generated with ChatGPT assistance and executed in its Python environment on 15 November 2026. They are supplied for student review and verification. Do not claim to have run these locally unless you have. Do not claim semester-long development: commit timestamps should reflect actual work. The student must review the implementation, customise the reflection, declare assistance and understand the submitted material. The distributed design is proposed, not implemented.

## References
- Assessment brief: https://lms-assets.miva.university/course-materials/mit-8103-advanced-database-systems-ca-september-cohort-2026.pdf
- SQLite isolation: https://www.sqlite.org/isolation.html
- SQLite query plans: https://www.sqlite.org/eqp.html
- Python DBM: https://docs.python.org/3/library/dbm.html
- Python sqlite3: https://docs.python.org/3/library/sqlite3.html
