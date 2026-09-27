env "local" {
  src = "file://schema.hcl" # main branch
  dev = "docker://postgres/17/dev?search_path=public"

  migration {
    dir = "file://migrations"
  }

  format {
    migrate {
      diff = "{{ sql . \"  \" }}"
    }
  }
}

env "auxiliary" {
  src = "file://schema_aux.hcl"
  dev = "docker://postgres/17/dev?search_path=public"

  migration {
    dir = "file://migrations_aux"
  }
}
