/*
 * `hicpup plot` - the Module A figures.
 *
 * Two of hicpup's four `--kind` values are wired up:
 *
 *   profiles-by-view  the deliverable. One panel per view, all samples
 *                     overlaid - this is the control-vs-treatment comparison.
 *   matrix            per-sample pileup heatmap, useful as a sanity check that
 *                     the pileup is not empty.
 *
 * `window-grid` is not wired up: it needs a per-window pileup
 * (`hicpup pileup --by-window --no-local`), which is a different invocation from
 * the averaged pileup the rest of the chain uses. Feeding it the averaged .pkl
 * fails with KeyError: 'chrom'.
 *
 * Only views that actually have a fountain BED are ever passed in. Asking for a
 * view with no data does not fail - plot_cone_profiles_by_view draws an empty
 * panel and matplotlib only warns - so main.nf derives the list rather than
 * taking it as a parameter.
 */

process PLOT_PROFILES {
    label 'process_low'
    container params.hicpup_container

    publishDir "${params.outdir}/figures", mode: params.publish_dir_mode, pattern: "*.pdf"

    input:
    path profile
    val  views

    output:
    path "cone_profiles.pdf", emit: figure
    path "versions.yml",      emit: versions

    script:
    """
    hicpup plot \\
        --kind profiles-by-view \\
        --profile ${profile} \\
        --views ${views.join(',')} \\
        --output cone_profiles.pdf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        hicpup: \$(python -c "from importlib.metadata import version; print(version('hicpup'))")
        matplotlib: \$(python -c "from importlib.metadata import version; print(version('matplotlib'))")
    END_VERSIONS
    """
}

process PLOT_MATRIX {
    tag "${meta.id}_${view}"
    label 'process_low'
    container params.hicpup_container

    publishDir "${params.outdir}/figures", mode: params.publish_dir_mode, pattern: "*.pdf"

    input:
    tuple val(meta), path(pileup), val(view)

    output:
    path "${meta.id}.${view}.matrix.pdf", emit: figure
    path "versions.yml",                  emit: versions

    script:
    """
    hicpup plot \\
        --kind matrix \\
        --pileup ${pileup} \\
        --strain ${meta.strain} \\
        --replicate ${meta.replicate} \\
        --view ${view} \\
        --log2 \\
        --output ${meta.id}.${view}.matrix.pdf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        hicpup: \$(python -c "from importlib.metadata import version; print(version('hicpup'))")
    END_VERSIONS
    """
}
