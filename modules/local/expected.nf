/*
 * `hicpup expected` - cis expected contact frequency, one task per sample.
 *
 * hicpup's CLI is config-driven rather than per-file: it reads a YAML declaring
 * every cooler and loops over all (strain, replicate) x view combinations
 * internally. This pipeline fans out one task per sample instead, so
 * write_hicpup_config.py emits a YAML declaring exactly one cooler. The views
 * (genome/A/X) are always derived from the chrom.sizes, never passed in.
 *
 * No fountain BED is staged here: `expected` never loads features, and
 * config.load_config only requires the `features` key to exist, not to be
 * populated or to point at anything real.
 */
process EXPECTED {
    tag "$meta.id"
    label 'process_medium'
    container params.hicpup_container

    publishDir "${params.outdir}/expected", mode: params.publish_dir_mode, pattern: "*.parquet"

    input:
    tuple val(meta), path(cool)
    path chromsizes

    output:
    tuple val(meta), path("${meta.id}.expected.parquet"), emit: expected
    path "versions.yml",                                  emit: versions

    script:
    """
    write_hicpup_config.py \\
        --strain ${meta.strain} \\
        --replicate ${meta.replicate} \\
        --cool ${cool} \\
        --chromsizes ${chromsizes} \\
        --resolution ${params.resolution} \\
        --output hicpup_config.yaml

    hicpup expected \\
        --config hicpup_config.yaml \\
        --output ${meta.id}.expected.parquet \\
        --nproc ${task.cpus}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        hicpup: \$(python -c "from importlib.metadata import version; print(version('hicpup'))")
        cooltools: \$(python -c "from importlib.metadata import version; print(version('cooltools'))")
        cooler: \$(python -c "from importlib.metadata import version; print(version('cooler'))")
    END_VERSIONS
    """
}
