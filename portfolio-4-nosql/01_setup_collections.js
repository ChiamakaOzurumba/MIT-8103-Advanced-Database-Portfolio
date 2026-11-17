// Portfolio 4 - MongoDB: collection setup with $jsonSchema validators
// Student: Chiamaka Ozurumba (2026/A/MIT/1005)
// Rules: validators use oneOf (never if/then/else); never use the `use` helper.
db = db.getSiblingDB("mediaarchive");

db.catalogue.drop();
db.access_logs.drop();
db.preservation_logs.drop();

// Catalogue documents: ARCHIVED assets MUST carry a checksum (enforced via oneOf).
db.createCollection("catalogue", {
  validator: { $jsonSchema: {
    bsonType: "object",
    required: ["assetId", "title", "medium", "status", "collectionCode", "acquiredAt"],
    properties: {
      assetId:        { bsonType: "int", description: "asset identifier" },
      title:          { bsonType: "string", minLength: 1 },
      medium:         { enum: ["AUDIO", "VIDEO", "PHOTO", "DOCUMENT"] },
      status:         { enum: ["DRAFT", "CATALOGUED", "ARCHIVED", "DEPRECATED"] },
      collectionCode: { bsonType: "string", pattern: "^[A-Z0-9_-]+$" },
      acquiredAt:     { bsonType: "date" },
      checksum:       { bsonType: ["string", "null"] },
      durationSec:    { bsonType: ["int", "long", "null"] },
      contributors:   { bsonType: ["array", "null"] }
    },
    oneOf: [
      { properties: { status: { enum: ["ARCHIVED"] } }, required: ["checksum"] },
      { properties: { status: { enum: ["DRAFT"] } } },
      { properties: { status: { enum: ["CATALOGUED"] } } },
      { properties: { status: { enum: ["DEPRECATED"] } } }
    ]
  } },
  validationLevel: "strict",
  validationAction: "error"
});

// Access logs (loans): status enum + barcode pattern + date range.
db.createCollection("access_logs", {
  validator: { $jsonSchema: {
    bsonType: "object",
    required: ["copyBarcode", "userId", "status", "startAt", "endAt"],
    properties: {
      copyBarcode: { bsonType: "string", pattern: "^[A-Z0-9-]+$" },
      userId:      { bsonType: "int" },
      status:      { enum: ["REQUESTED", "APPROVED", "ACTIVE", "RETURNED", "OVERDUE", "REJECTED"] },
      startAt:     { bsonType: "date" },
      endAt:       { bsonType: "date" }
    },
    oneOf: [
      { properties: { status: { enum: ["REJECTED"] } }, required: ["notes"] },
      { properties: { status: { enum: ["REQUESTED"] } } },
      { properties: { status: { enum: ["APPROVED"] } } },
      { properties: { status: { enum: ["ACTIVE"] } } },
      { properties: { status: { enum: ["RETURNED"] } } },
      { properties: { status: { enum: ["OVERDUE"] } } }
    ]
  } },
  validationLevel: "strict",
  validationAction: "error"
});

// Preservation logs: DISPOSAL MUST carry notes (enforced via oneOf).
db.createCollection("preservation_logs", {
  validator: { $jsonSchema: {
    bsonType: "object",
    required: ["assetId", "action", "eventDate", "operator", "outcome"],
    properties: {
      assetId:   { bsonType: "int" },
      action:    { enum: ["INSPECTION", "MIGRATION", "RESTORATION", "REPAIR", "DISPOSAL"] },
      eventDate: { bsonType: "date" },
      operator:  { bsonType: "string", minLength: 1 },
      outcome:   { bsonType: "string", minLength: 1 },
      notes:     { bsonType: ["string", "null"] }
    },
    oneOf: [
      { properties: { action: { enum: ["DISPOSAL"] } }, required: ["notes"] },
      { properties: { action: { enum: ["INSPECTION"] } } },
      { properties: { action: { enum: ["MIGRATION"] } } },
      { properties: { action: { enum: ["RESTORATION"] } } },
      { properties: { action: { enum: ["REPAIR"] } } }
    ]
  } },
  validationLevel: "strict",
  validationAction: "error"
});

print("collections_created: " + db.getCollectionNames().join(", "));
