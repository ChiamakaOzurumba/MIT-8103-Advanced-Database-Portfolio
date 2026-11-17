// Portfolio 4 - MongoDB: bulk data load (>= 40,000 documents)
// Student: Chiamaka Ozurumba (2026/A/MIT/1005)
// 42,000 catalogue + 5,000 access_logs + 6,000 preservation_logs = 53,000 docs.
// NumberLong values are constructed with string arguments, e.g. NumberLong("42000").
db = db.getSiblingDB("mediaarchive");

db.catalogue.deleteMany({});
db.access_logs.deleteMany({});
db.preservation_logs.deleteMany({});

const operators = [
  "Chiamaka Ozurumba", "Emeka Nwosu", "Ngozi Okoye", "Tunde Bakare",
  "Adaeze Eze", "Musa Abdullahi", "Zainab Bello", "Daniel Okafor",
  "Folake Adeyemi", "Segun Adeyemi", "Aisha Mohammed", "Chidi Obi"
];
const actions = ["INSPECTION", "MIGRATION", "RESTORATION", "REPAIR", "DISPOSAL"];
const outcomes = ["PASSED", "PASSED WITH NOTES", "FLAGGED", "COMPLETED"];
const collectionCodes = ["NTA-LAG", "NOLLY", "AFRO-HL", "NTA-NEWS", "NTA-DRAMA", "FELA", "SUNNY-ADE"];
const titles = ["News Bulletin", "Drama Episode", "Music Documentary", "Independence Footage",
                "Election Coverage", "Football Highlights", "Highlife Session", "Afrobeat Live"];
const roles = ["CREATOR", "DIRECTOR", "PRODUCER", "PERFORMER", "EDITOR", "CINEMATOGRAPHER"];
const mediums = ["VIDEO", "AUDIO", "PHOTO", "DOCUMENT"];
const statuses = ["DRAFT", "CATALOGUED", "ARCHIVED", "CATALOGUED", "DEPRECATED"];

const start = ISODate("2024-01-01T00:00:00Z");
const dayMs = 24 * 60 * 60 * 1000;

// 42,000 catalogue docs, batched at 5,000 each.
let inserted = 0;
for (let batch = 0; batch < 9 && inserted < 42000; batch++) {
  const docs = [];
  for (let i = 0; i < 5000 && inserted < 42000; i++) {
    const n = batch * 5000 + i;
    const status = statuses[n % statuses.length];
    docs.push({
      _id: n + 1,
      assetId: NumberInt(n + 1),
      title: titles[n % 8] + " " + n,
      medium: mediums[n % 4],
      status: status,
      collectionCode: collectionCodes[n % 7],
      acquiredAt: new Date(start.getTime() + (n % 700) * dayMs),
      checksum: status === "ARCHIVED" ? "sha256-" + n.toString(16).padStart(8, "0") : null,
      durationSec: NumberInt(600 + (n % 1800)),
      contributors: [{
        creatorId: NumberInt((n % 20) + 1),
        name: operators[n % 12],
        role: roles[n % 6]
      }]
    });
    inserted++;
  }
  if (docs.length) db.catalogue.insertMany(docs, { ordered: false });
}

// 5,000 access logs. REJECTED ones carry notes (validator oneOf requirement).
const accessDocs = [];
for (let i = 0; i < 5000; i++) {
  const status = ["REQUESTED", "APPROVED", "ACTIVE", "RETURNED", "OVERDUE", "REJECTED"][i % 6];
  const startAt = new Date(start.getTime() + (i % 300) * dayMs);
  accessDocs.push({
    copyBarcode: "NDMA-" + String((i % 60) + 1).padStart(5, "0"),
    userId: NumberInt((i % 8) + 5),
    status: status,
    startAt: startAt,
    endAt: new Date(startAt.getTime() + dayMs),
    notes: status === "REJECTED" ? "Rejected: licence conflict" : null
  });
}
db.access_logs.insertMany(accessDocs, { ordered: false });

// 6,000 preservation logs. DISPOSAL ones carry notes (validator oneOf requirement).
const presDocs = [];
for (let i = 0; i < 6000; i++) {
  const action = actions[i % 5];
  presDocs.push({
    assetId: NumberInt((i % 40) + 1),
    action: action,
    eventDate: new Date(start.getTime() + (i % 700) * dayMs),
    operator: operators[i % 12],
    outcome: outcomes[i % 4],
    notes: action === "DISPOSAL" ? "Disposed after retention review" : null
  });
}
db.preservation_logs.insertMany(presDocs, { ordered: false });

const catCount = db.catalogue.countDocuments();
print("catalogue_count: " + catCount + " (NumberLong total = " + NumberLong(String(catCount)) + ")");
print("access_logs_count: " + db.access_logs.countDocuments());
print("preservation_logs_count: " + db.preservation_logs.countDocuments());
print("grand_total: " + (catCount + db.access_logs.countDocuments() + db.preservation_logs.countDocuments()));
