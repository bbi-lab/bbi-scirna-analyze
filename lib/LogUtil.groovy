/*
** Software logging utility.
** Usage fragment:
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
  static String emit(List<Map> tools, String process, String taskIndex, String container,
                     String nfVersion, String pipelineVersion, String sample) {
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
    L << "     --arg     process     \"${process}\" \\"
    L << "     --arg     task_id     \"${taskIndex}\" \\"
    L << "     --arg     container    \"${container}\" \\"
    L << "     --arg     nf_version   \"${nfVersion}\" \\"
    L << "     --arg     pipeline     \"${pipelineVersion}\" \\"
    L << "     --arg     timestamp    \"\$(date -u +%Y-%m-%dT%H:%M:%SZ)\" \\"
    L << "     '{sample: \$sample, process: \$process, task_id: \$task_id, " +
          "container: \$container, nf_version: \$nf_version, " +
          "pipeline: \$pipeline, \$timestamp, software: \$software}' > version.json"

    // 5. Remove temp files
    L << "rm -f .tool_*.json .tool_*.cmd .software.json .*.version"

    return L.join('\n')
  }
}

