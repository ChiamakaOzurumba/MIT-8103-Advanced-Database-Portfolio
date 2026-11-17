// Portfolio 4 - MongoDB: aggregation pipelines (5)
// Student: Chiamaka Ozurumba (2026/A/MIT/1005)
db = db.getSiblingDB("mediaarchive");

print("--- A1: assets per collection, with archived count ---");
printjson(db.catalogue.aggregate([
  { $group: {
      _id: "$collectionCode",
      total:    { $sum: 1 },
      archived: { $sum: { $cond: [{ $eq: ["$status", "ARCHIVED"] }, 1, 0] } }
  } },
  { $sort: { total: -1 } }
]).toArray());

print("--- A2: top 5 assets by preservation event count (join via $lookup) ---");
printjson(db.preservation_logs.aggregate([
  { $group: { _id: "$assetId", events: { $sum: 1 } } },
  { $sort: { events: -1 } },
  { $limit: 5 },
  { $lookup: { from: "catalogue", localField: "_id", foreignField: "assetId", as: "asset" } },
  { $unwind: "$asset" },
  { $project: { _id: 0, assetId: "$_id", title: "$asset.title", events: 1 } }
]).toArray());

print("--- A3: monthly preservation events ---");
printjson(db.preservation_logs.aggregate([
  { $group: { _id: { $dateToString: { format: "%Y-%m", date: "$eventDate" } }, events: { $sum: 1 } } },
  { $sort: { _id: 1 } }
]).toArray());

print("--- A4: access log status distribution ---");
printjson(db.access_logs.aggregate([
  { $group: { _id: "$status", count: { $sum: 1 } } },
  { $sort: { count: -1 } }
]).toArray());

print("--- A5: outcome breakdown per preservation action ---");
printjson(db.preservation_logs.aggregate([
  { $group: { _id: { action: "$action", outcome: "$outcome" }, count: { $sum: 1 } } },
  { $sort: { "_id.action": 1, "_id.outcome": 1 } }
]).toArray());
