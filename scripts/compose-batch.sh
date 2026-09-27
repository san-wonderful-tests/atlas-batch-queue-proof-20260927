#!/usr/bin/env bash
set -Eeuo pipefail

if (($# < 1)); then
  echo 'usage: scripts/compose-batch.sh <local-pr-ref>...' >&2
  exit 1
fi
if [[ -n $(git status --porcelain) ]]; then
  echo 'Start from a clean batch branch.' >&2
  exit 1
fi

base_ref=origin/main
if [[ $(git rev-parse HEAD) != $(git rev-parse "${base_ref}") ]]; then
  echo 'Start the batch branch at the current origin/main commit.' >&2
  exit 1
fi

migration_dirs=(migrations migrations_aux)
archive_root=$(mktemp -d)
trap 'rm -rf -- "${archive_root}"' EXIT
batch_name=$(git branch --show-current)
batch_name=${batch_name//\//-}
if [[ ! ${batch_name} =~ ^[[:alnum:]_.-]+$ ]]; then
  echo 'The batch branch name cannot be used as a manifest filename.' >&2
  exit 1
fi
mkdir -p batch-manifests
manifest_path="batch-manifests/${batch_name}.tsv"
if [[ -e ${manifest_path} ]]; then
  echo "Manifest already exists: ${manifest_path}" >&2
  exit 1
fi
printf 'source_sha\told_path\tnew_path\tsql_sha256\n' > "${manifest_path}"

for ref in "$@"; do
  source_sha=$(git rev-parse "${ref}^{commit}")
  candidate_base=$(git merge-base "${base_ref}" "${source_sha}")
  if [[ -n $(git diff --name-only "${candidate_base}...${source_sha}" -- atlas.hcl .github scripts) ]]; then
    echo "${ref} changes trusted Atlas or workflow inputs; review separately." >&2
    exit 1
  fi

  added_sql=()
  while IFS= read -r path; do
    [[ -n ${path} ]] && added_sql+=("${path}")
  done < <(git diff --name-only --diff-filter=A "${candidate_base}...${source_sha}" -- 'migrations/*.sql' 'migrations_aux/*.sql')
  if ((${#added_sql[@]} == 0)); then
    echo "${ref} has no new Atlas SQL." >&2
    exit 1
  fi
  if [[ -n $(git diff --name-only --diff-filter=MDR "${candidate_base}...${source_sha}" -- 'migrations/*.sql' 'migrations_aux/*.sql') ]]; then
    echo "${ref} edits or removes existing migration history." >&2
    exit 1
  fi

  mkdir -p "${archive_root}/${source_sha}"
  for path in "${added_sql[@]}"; do
    mkdir -p "${archive_root}/${source_sha}/$(dirname "${path}")"
    git show "${source_sha}:${path}" > "${archive_root}/${source_sha}/${path}"
  done

  if ! git merge --no-ff --no-commit "${source_sha}"; then
    conflicts=()
    while IFS= read -r path; do
      [[ -n ${path} ]] && conflicts+=("${path}")
    done < <(git diff --name-only --diff-filter=U)
    if ((${#conflicts[@]} == 0)); then
      git merge --abort
      echo "${ref} could not merge." >&2
      exit 1
    fi
    for path in "${conflicts[@]}"; do
      if [[ ${path} != migrations/atlas.sum && ${path} != migrations_aux/atlas.sum ]]; then
        git merge --abort
        echo "${ref} conflicts outside atlas.sum: ${path}" >&2
        exit 1
      fi
      git checkout --ours -- "${path}"
      git add -- "${path}"
    done
  fi
  git commit --no-edit

  for migration_dir in "${migration_dirs[@]}"; do
    owned_sql=()
    for path in "${added_sql[@]}"; do
      [[ ${path} == "${migration_dir}/"* ]] && owned_sql+=("${path}")
    done
    ((${#owned_sql[@]} > 0)) || continue

    migration_url="file://${PWD}/${migration_dir}"
    for path in "${owned_sql[@]}"; do
      git rm -- "${path}"
    done
    atlas migrate hash --config file:///dev/null --dir "${migration_url}"

    for path in "${owned_sql[@]}"; do
      filename=${path##*/}
      if [[ ! ${filename} =~ ^[0-9]{14}_(.+)\.sql$ ]]; then
        echo "Invalid Atlas migration filename: ${path}" >&2
        exit 1
      fi
      migration_name=${BASH_REMATCH[1]}
      atlas migrate new --config file:///dev/null --dir "${migration_url}" "${migration_name}"
      allocated_name=$(tail -n 1 "${migration_dir}/atlas.sum" | cut -d ' ' -f 1)
      new_path="${migration_dir}/${allocated_name}"
      if [[ ! ${allocated_name} =~ ^[0-9]{14}_${migration_name}\.sql$ || ! -f ${new_path} ]]; then
        echo "Atlas did not allocate an expected filename for ${path}." >&2
        exit 1
      fi
      cp -- "${archive_root}/${source_sha}/${path}" "${new_path}"
      atlas migrate hash --config file:///dev/null --dir "${migration_url}"
      sql_sha=$(shasum -a 256 "${new_path}" | awk '{print $1}')
      printf '%s\t%s\t%s\t%s\n' "${source_sha}" "${path}" "${new_path}" "${sql_sha}" >> "${manifest_path}"
    done
    git add -A -- "${migration_dir}"
  done
  git add "${manifest_path}"
  git commit -m "Finalize Atlas SQL from ${ref}"
done

for env_name in local auxiliary; do
  atlas migrate validate --env "${env_name}"
  atlas migrate diff "batch_verify_${env_name}_no_drift" --env "${env_name}"
done
if [[ -n $(git status --porcelain -- migrations migrations_aux) ]]; then
  echo 'Combined SQL does not match the desired schemas.' >&2
  git status --short -- migrations migrations_aux
  exit 1
fi

echo "Composed $# PR head(s); ${manifest_path} records every SQL rename."
