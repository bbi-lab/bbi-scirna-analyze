process make_genome_files_json {
  input:
  path(samplesheet_file)
  val(star_genomes_file)

  output:
  path("genome_files.json"), emit: genome_files

  script:
  """
  # bash watch for errors
  set -ueo pipefail

  $workflow.projectDir/bin/make_genome_files.py -i $samplesheet_file -g ${star_genomes_file}
  """
}
