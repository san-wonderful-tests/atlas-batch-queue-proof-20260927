-- Create "tasks" table
CREATE TABLE "tasks" (
  "id" uuid NOT NULL,
  "tenant_id" uuid NOT NULL,
  "title" text NOT NULL,
  PRIMARY KEY ("id")
);
-- Create index "idx_tasks_tenant_title" to table: "tasks"
CREATE UNIQUE INDEX "idx_tasks_tenant_title" ON "tasks" ("tenant_id", "title");
