/*
** Software logging utility.
** Usage fragment:
**
**  process VARIANT_CALLING {
**    container 'quay.io/seqera/gatk:4.5.0.0'
**    input:
**    path bam
**    path fasta
**    output:
**    path 'variants.vcf'
**    path 'version.json', emit: 'version'
**    path 'command_provenance.txt', emit: 'provenance'
**
**    script:
**    """
**    ${LogUtil.emit([
**      [ tool: 'samtools',
**         cmdVer:  'samtools --version',
**         command: "samtools sort -@ ${task.cpus} -o sorted.bam ${bam}" ],
**   
**       [ tool: 'gatk',
**         cmdVer:  'gatk --version',
**         command: "gatk HaplotypeCaller -R ${fasta} -I sorted.bam -O variants.vcf" ],
**   
**       [ tool: 'bcftools',
**         cmdVer:  'bcftools --version',
**         command: "bcftools norm -f ${fasta} variants.vcf -Ov -o variants_norm.vcf" ]
**     ])}
**   
**    # ---- actual work ----
**
**    samtools sort -@ ${task.cpus} -o sorted.bam ${bam}
**    gatk HaplotypeCaller -R ${fasta} -I sorted.bam -O variants.vcf
**    bcftools norm -f ${fasta} variants.vcf -Ov -o variants_norm.vcf
**    """
**
** Notes:
**   o  watch for $ and double quotes and other shell metacharacters, which
**      may need to be escaped.
**   o  the process must put version.json/command_provenance.txt into
**      a channel/publishDir (after renaming it?)
**   o  process the log json files as follows
**
** ```groovy
** // Collect every emitted channel
** def logChannels = [
**   FASTQ_DUMPS.version,
**   FASTQ_DUMPS.provenance,
**   BOWTIE_ALIGN.version,
**   BOWTIE_ALIGN.provenance,
**   VCF_CALL.version,
**   VCF_CALL.provenance,
**   // ...
** ]
** 
** logChannels
**    .inject(Channel.empty()) { acc, ch -> acc.mix(ch) }
**    .collect()
**    .into(AGGREGATE_LOGS)
** ```
**
** Aggregate log json data.
**
** process AGGREGATE_LOGS {
**     input:
**     path log_files                       // List<File> from .collect()
** 
**     output:
**     path 'all_versions.json'
**     path 'all_commands.txt'
** 
**     script:
**     """
**     # Merge every per-task version.json into one JSON array
**     jq -s '
**         sort_by(.process, .task_id) |
**         map({
**             process   : .process,
**             task_id   : .task_id,
**             attempt   : .attempt,
**             container : .container,
**             nf_version: .nf_version,
**             pipeline  : .pipeline,
**             timestamp : .timestamp,
**             command   : .command
**         })
**      ' ${log_files} > all_versions.json
** 
**     # Concatenate human-readable command records
**     cat ${log_files} | grep -v '^#' > all_commands.txt
**      """
** }
** 
** or
** 
** process AGGREGATE_LOGS {
**     input:  path log_files
**     output: path 'aggregated_versions.json'
** 
**     script:
**      """
**     jq -s '
**         sort_by(.process, .task_id) |
**         unique_by(.task_id, .attempt) |
**         map({
**             process   : .process,
**             task_id   : .task_id,
**             attempt   : .attempt,
**             container : .container,
**             command   : .command,
**             timestamp : .timestamp
**         })
**      ' ${log_files} > aggregated_versions.json
**      """
** }
** 
*/

/*
** Heredoc variant for commands with special characters
*/
class LogUtil {

  /**
   * Generate shell code that captures version info for multiple tools
   * into a single version.json and a command_provenance.txt.
   *
   * @param tools  List of maps, each with:
   *    - tool     (String)  software name, e.g. "bowtie2"
   *    - cmdVer   (String)  shell command that prints the version, e.g. "bowtie2 --version"
   *    - command  (String)  the main command line for provenance
   */
  static String emit(List<Map> tools, nextflow, task, params, sample) {
    def L = []

    // 1. Capture each tool's version string
    tools.each { t ->
      L << "${t.cmdVer} 2>&1 | head -1 > .${t.tool}.version"
    }

    // 2. Build one JSON fragment per tool
    tools.eachWithIndex { t, i ->
      L << "cat > .tool_${i}.cmd << 'PROV_${i}'"
      L << "${t.command}"
      L << "PROV_${i}"
      L << "jq -n \\"
      L << "    --arg name \"${t.tool}\" \\"
      L << "    --arg version \"\$(cat .${t.tool}.version)\" \\"
      L << "    --rawfile command .tool_${i}.cmd \\"
      L << "    '{name: \$name, version: \$version, command: \$command}' > .tool_${i}.json"
    }

    // 3. Merge fragments into a JSON array
    L << "jq -s '.' .tool_*.json > .software.json"

    // 4. Assemble the final version.json
    L << "jq -n \\"
    L << "     --slurpfile software .software.json \\"
    L << "     --arg     sample      \"${sample}\" \\"
    L << "     --arg     process     \"${task.process}\" \\"
    L << "     --arg     task_id     \"${task.index}\" \\"
    L << "     --argjson attempt      ${task.attempt} \\"
    L << "     --arg     container    \"${task.container}\" \\"
    L << "     --arg     nf_version   \"${nextflow.version}\" \\"
    L << "     --arg     pipeline     \"${params.version}\" \\"
    L << "     --arg     timestamp    \"\$(date -u +%Y-%m-%dT%H:%M:%SZ)\" \\"
    L << "     '{sample: \$sample, process: \$process, task_id: \$task_id, " +
          "attempt: \$attempt, container: \$container, nf_version: \$nf_version, " +
          "pipeline: \$pipeline, timestamp: \$timestamp, software: \$software}' > version.json"

/*
    // 5. Human-readable command provenance
    L << "{ echo \"# task: ${task.id}  process: ${task.processName}  attempt: ${task.attempt}\";"
    L << "  echo \"# container: ${task.container}\";"
    tools.each { t ->
      L << "  printf '%s\\n' \"${t.command}\";"
    }
    L << "} > command_provenance.txt"
*/

    // 6. Remove temp files
    // L << "rm -f .tool_*.json .software.json .*.version"
    L << "rm -f .tool_*.json .tool_*.cmd .software.json .*.version"

    return L.join('\n')
  }
}


