process make_mito_umis_json {
  input:
  path(samplesheet_file)
  val(star_genomes_file)
  val(dummy)

  output:
  path("mito_umi.json"), emit: mito_umis

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  $workflow.projectDir/bin/make_mito_umis_json.py -i $samplesheet_file -g $star_genomes_file
  """
}
