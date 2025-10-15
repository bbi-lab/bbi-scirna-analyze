process make_umi_counts_json {
  input:
  path(samplesheet_file)
  val(star_genomes_file)
  val(dummy)

  output:
  path("umi_counts.json"), emit: umi_counts

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  $workflow.projectDir/bin/make_umi_counts_json.py -i $samplesheet_file -g $star_genomes_file
  """
}
