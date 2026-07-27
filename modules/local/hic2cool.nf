/*
 * Juicer .hic -> cooler. Only reached in `-profile full`; GEO deposits .hic
 * while hicpup/cooltools consume .cool.
 *
 * `-r <resolution>` extracts a single resolution into a .cool. Passing `-r 0`
 * would produce a multi-resolution .mcool instead, which hicpup cannot address:
 * io.load_coolers calls Path.exists() on the configured path, so the
 * `file.mcool::/resolutions/1000` URI form fails before cooler is reached.
 */
process HIC2COOL {
    tag "$meta.id"
    label 'process_medium'
    container params.hic2cool_container

    publishDir "${params.outdir}/cooler", mode: params.publish_dir_mode, pattern: "*.cool"

    input:
    tuple val(meta), path(hic)

    output:
    tuple val(meta), path("${meta.id}.cool"), emit: cool
    path "versions.yml",                      emit: versions

    script:
    """
    hic2cool convert \\
        ${hic} \\
        ${meta.id}.cool \\
        -r ${params.resolution} \\
        -p ${task.cpus}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        hic2cool: \$(python -c "from importlib.metadata import version; print(version('hic2cool'))")
        cooler: \$(python -c "from importlib.metadata import version; print(version('cooler'))")
    END_VERSIONS
    """
}
