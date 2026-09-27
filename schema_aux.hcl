schema "public" {
}

table "audit_items" {
  schema = schema.public

  column "id" {
    type = uuid
    null = false
  }

  column "name" {
    type = text
    null = false
  }

  column "batch_a" {
    type = bigint
    null = true
  }

  primary_key {
    columns = [column.id]
  }
}

table "batch_b_events" {
  schema = schema.public

  column "id" {
    type = uuid
    null = false
  }

  primary_key {
    columns = [column.id]
  }
}
