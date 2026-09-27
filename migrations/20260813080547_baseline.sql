-- Create "projects" table
CREATE TABLE "projects" (
  "id" uuid NOT NULL,
  "tenant_id" uuid NOT NULL,
  "name" text NOT NULL,
  PRIMARY KEY ("id")
);
-- Create index "idx_projects_tenant_name" to table: "projects"
CREATE UNIQUE INDEX "idx_projects_tenant_name" ON "projects" ("tenant_id", "name");
