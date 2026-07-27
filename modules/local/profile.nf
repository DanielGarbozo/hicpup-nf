/*
 * `hicpup profile` - the 60-degree cone profile, one tidy TSV row per
 * (strain, replicate, view, position).
 *
 * The output carries its own identity columns, which is what lets main.nf merge
 * every sample's TSV with a plain header-preserving concatenation instead of a
 * join process.
 *
 * `--ndiags` is bounded by the pileup matrix size: cone.cone_diagonals stacks
 * antidiagonals at offsets [-ndiags, ndiags), and past a matrix-dependent limit
 * they stop being the same length and np.vstack fails with an opaque IndexError.
 * For a 41x41 matrix (flank=20 kb at 1 kb bins) the limit is 17.
 */
process PROFILE {
    tag "$meta.id"
    label 'process_low'
    container params.hicpup_container

    publishDir "${params.outdir}/profile", mode: params.publish_dir_mode, pattern: "*.tsv"

    input:
    tuple val(meta), path(pileup)

    output:
    tuple val(meta), path("${meta.id}.profile.tsv"), emit: profile
    path "versions.yml",                             emit: versions

    script:
    """
    hicpup profile \\
        --pileup ${pileup} \\
        --output ${meta.id}.profile.tsv \\
        --cone-angle ${params.cone_angle} \\
        --ndiags ${params.ndiags}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        hicpup: \$(python -c "from importlib.metadata import version; print(version('hicpup'))")
    END_VERSIONS
    """
}
