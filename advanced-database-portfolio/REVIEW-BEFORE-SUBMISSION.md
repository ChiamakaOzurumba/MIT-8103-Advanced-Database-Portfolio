# Your short review
1. In schema.sql, find PRIMARY KEY(student_id,offering_id). It prevents the same student registering twice for the same offering.
2. Look at er-diagram.png: enrolments joins students to offerings; courses can run in different terms.
3. Open evidence/query-plans.txt. Compare SCAN before indexing with SEARCH using the new index. Read the measured times; they are not promised production speeds.
4. Open evidence/transactions.txt. Commit saves; rollback reverses; isolation hides unfinished changes; the writer lock and capacity check protect the last seat.
5. Open evidence/nosql.txt. Preferences are stored by key and survive closing/reopening the store. NoSQL here is a local key-value database, not MongoDB or a deployed cloud system.
6. Read the distributed/cloud README. Replication copies data, sharding divides data and backups support recovery. That design is proposed only.
7. Write a truthful personal reflection: Which choice can you explain? What was hardest to understand? What limitation would you address next? Do not copy a claim about experience you did not have.
8. Complete the summary's matriculation number, GitHub URL, reflection and review declaration. Reopen the saved PDF and check the entries.
9. Make the GitHub repository PRIVATE. Upload the extracted folders/files, not just the ZIP. Give the assessor access using the identity supplied by the course; check the invitation is accepted. A private URL alone does not grant access.
10. Submit the completed 3-page summary through the correct MIT 8103 LMS portal and retain the confirmation. This package itself does not submit anything.
