/*
 * `hicpup pileup` - fountain pileups over the anchors in the fountain BEDs.
 *
 * hicpup maps view -> feature key by convention (pileup._VIEW_FEATURE_KEYS:
 * X -> fountains_x, A -> fountains_a). A view whose key is absent from the
 * config is skipped with a warning, which is why `fountains_a` is an optional
 * input: pass `[]` and the run analyses view X only. main.nf keeps the rest of
 * the pipeline consistent with that by deriving its view list the same way.
 *
 * `--flank` must fit the chromosome: coolpuppy silently piles up 0 windows and
 * returns an all-NaN matrix when the requested window runs off the end, so an
 * oversized flank produces a green run with an empty figure rather than an error.
 */
process PILEUP {
    tag "$meta.id"
    label 'process_medium'
    container params.hicpup_container

    publishDir "${params.outdir}/pileup", mode: params.publish_dir_mode, pattern: "*.pkl"

    input:
    tuple val(meta), path(cool), path(expected)
    path chromsizes
    path fountains_x
    path fountains_a

    output:
    tuple val(meta), path("${meta.id}.pileup.pkl"), emit: pileup
    path "versions.yml",                            emit: versions

    script:
    def fountains_a_arg = fountains_a ? "--fountains-a ${fountains_a}" : ''
    """
    write_hicpup_config.py \\
        --strain ${meta.strain} \\
        --replicate ${meta.replicate} \\
        --cool ${cool} \\
        --chromsizes ${chromsizes} \\
        --resolution ${params.resolution} \\
        --fountains-x ${fountains_x} \\
        ${fountains_a_arg} \\
        --output hicpup_config.yaml

    hicpup pileup \\
        --config hicpup_config.yaml \\
        --expected ${expected} \\
        --output ${meta.id}.pileup.pkl \\
        --flank ${params.flank} \\
        --local \\
        --min-diag ${params.min_diag} \\
        --nproc ${task.cpus}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        hicpup: \$(python -c "from importlib.metadata import version; print(version('hicpup'))")
        coolpuppy: \$(python -c "from importlib.metadata import version; print(version('coolpuppy'))")
    END_VERSIONS
    """
}
