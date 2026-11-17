// Portfolio 4 - MongoDB: before/after index demo
// Student: Chiamaka Ozurumba (2026/A/MIT/1005)
// Prints winning-plan stage, totalDocsExamined and executionTimeMillis for a
// find() query BEFORE (COLLSCAN) and AFTER (IXSCAN) creating an index.
// dropIndex is wrapped in try/catch.
db = db.getSiblingDB("mediaarchive");

const field = "collectionCode";
const filter = { collectionCode: "NOLLY" };

// Remove any existing index on the field so the BEFORE plan is a COLLSCAN.
try {
  db.catalogue.dropIndex(field + "_1");
} catch (e) {
  print("dropIndex skipped (no prior index): " + e.message);
}

function explainPlan(verbosity) {
  return db.runCommand({
    explain: { find: "catalogue", filter: filter },
    verbosity: verbosity
  });
}

function summarise(label, plan) {
  const qp = plan.queryPlanner || {};
  const es = plan.executionStats || {};
  const stage = (qp.winningPlan && qp.winningPlan.stage) || "n/a";
  print("--- " + label + " ---");
  print("stage: " + stage);
  print("docsExamined: " + es.totalDocsExamined);
  print("executionTimeMillis: " + es.executionTimeMillis);
}

print("filter under test: " + JSON.stringify(filter));
const before = explainPlan("executionStats");
summarise("BEFORE (no index on " + field + "; expect COLLSCAN)", before);

db.catalogue.createIndex({ collectionCode: 1 });
print("created index: " + field + "_1");

const after = explainPlan("executionStats");
summarise("AFTER (index on " + field + "; expect IXSCAN)", after);

print("docsExamined dropped from " +
  (before.executionStats ? before.executionStats.totalDocsExamined : "n/a") +
  " to " +
  (after.executionStats ? after.executionStats.totalDocsExamined : "n/a"));
