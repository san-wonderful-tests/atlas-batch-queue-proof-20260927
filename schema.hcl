schema "public" {
}

table "projects" {
  schema = schema.public

  column "id" {
    type = uuid
    null = false
  }

  column "tenant_id" {
    type = uuid
    null = false
  }

  column "name" {
    type = text
    null = false
  }

  column "owner_email" {
    type = text
    null = true
  }

  column "description" {
    type = text
    null = true
  }

  column "archived_at" {
    type = bigint
    null = true
  }

  column "batch_a" {
    type = bigint
    null = true
  }

  primary_key {
    columns = [column.id]
  }

  index "idx_projects_tenant_name" {
    unique  = true
    columns = [column.tenant_id, column.name]
  }
}

table "tasks" {
  schema = schema.public

  column "id" {
    type = uuid
    null = false
  }

  column "tenant_id" {
    type = uuid
    null = false
  }

  column "title" {
    type = text
    null = false
  }

  column "priority" {
    type = integer
    null = true
  }

  column "due_at" {
    type = bigint
    null = true
  }

  column "batch_b" {
    type = bigint
    null = true
  }

  primary_key {
    columns = [column.id]
  }

  index "idx_tasks_tenant_title" {
    unique  = true
    columns = [column.tenant_id, column.title]
  }
}
