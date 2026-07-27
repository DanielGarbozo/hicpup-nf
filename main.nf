#!/usr/bin/env nextflow
/*
 * hicpup-nf - downstream Hi-C fountain analysis.
 *
 *   FASTQ --[ nf-core/hic ]--> .hic / .cool --[ hicpup-nf ]--> cone profiles
 *           (upstream, cited, not run here)   (this pipeline)
 *
 *   HIC2COOL? -> EXPECTED -> PILEUP -> PROFILE -> PLOT
 *
 * The science lives in the hicpup package; this repo only chains and
 * containerises it. See modules/local/*.nf for what each process wraps.
 */

nextflow.enable.dsl = 2

include { HIC2COOL      } from './modules/local/hic2cool'
include { EXPECTED      } from './modules/local/expected'
include { PILEUP        } from './modules/local/pileup'
include { PROFILE       } from './modules/local/profile'
include { PLOT_PROFILES } from './modules/local/plot'
include { PLOT_MATRIX   } from './modules/local/plot'

/*
 * Resolve a samplesheet entry or asset path. Relative paths are resolved against
 * the pipeline directory, not the launch directory, so that
 * `nextflow run DanielGarbozo/hicpup-nf -profile test,docker` works from anywhere.
 */
def resolvePath(String path) {
    if (path ==~ /^(https?|ftp|s3|gs):\/\/.*/) {
        return file(path)
    }
    def resolved = file(path)
    return resolved.isAbsolute() ? file(path, checkIfExists: true)
                                 : file("${projectDir}/${path}", checkIfExists: true)
}

def helpMessage() {
    log.info """
    hicpup-nf ${workflow.manifest.version}

    Usage:
      nextflow run ${workflow.manifest.name} -profile test,docker --outdir results
      nextflow run ${workflow.manifest.name} -profile full,docker --outdir results_full

      nextflow run ${workflow.manifest.name} -profile docker \\
          --input samplesheet.csv --chromsizes ce10.chrom.sizes \\
          --fountains_x fountains_X.bed --outdir results

    Samplesheet columns: strain,replicate,matrix   (matrix = .cool or .hic, path or URL)
    """.stripIndent()
}

workflow {

    if (params.help) {
        helpMessage()
        return
    }

    // ---- Validate the inputs the pipeline cannot run without -----------------
    if (!params.input)       { error "Missing --input (samplesheet CSV). Run with --help." }
    if (!params.chromsizes)  { error "Missing --chromsizes. hicpup.views requires exactly 6 rows (5 autosomes + chrX)." }
    if (!params.fountains_x && !params.fountains_a) {
        error "Provide at least one fountain BED (--fountains_x and/or --fountains_a); with neither, hicpup pileup has nothing to pile up."
    }

    /*
     * Which views get analysed is not a free parameter: hicpup maps view -> feature
     * key by convention (X -> fountains_x, A -> fountains_a) and silently skips a
     * view whose BED is absent. Deriving the list from the BEDs actually provided
     * keeps PILEUP, PLOT_PROFILES and PLOT_MATRIX consistent with what hicpup did,
     * instead of letting a --views flag drift into asking for empty panels.
     * Order matches the reference notebooks: autosomes above, X below.
     */
    def active_views = []
    if (params.fountains_a) { active_views << 'A' }
    if (params.fountains_x) { active_views << 'X' }
    log.info "hicpup-nf: analysing view(s) ${active_views.join(', ')}"

    // ---- Shared reference assets (value channels: reused by every sample) ----
    ch_chromsizes  = Channel.value(resolvePath(params.chromsizes))
    ch_fountains_x = params.fountains_x ? Channel.value(resolvePath(params.fountains_x))
                                        : Channel.value([])
    ch_fountains_a = params.fountains_a ? Channel.value(resolvePath(params.fountains_a))
                                        : Channel.value([])

    // ---- Samplesheet --------------------------------------------------------
    ch_input = Channel.fromPath(resolvePath(params.input))
        | splitCsv(header: true)
        | map { row ->
            if (!row.strain || !row.replicate || !row.matrix) {
                error "Samplesheet row is missing strain/replicate/matrix: ${row}"
            }
            def meta = [
                id       : "${row.strain}_${row.replicate}",
                strain   : row.strain,
                replicate: row.replicate,
            ]
            [ meta, resolvePath(row.matrix) ]
        }

    // ---- .hic -> .cool, only for the entries that need it -------------------
    ch_branched = ch_input.branch { meta, matrix ->
        hic : matrix.name.endsWith('.hic')
        cool: true
    }

    HIC2COOL( ch_branched.hic )
    ch_cool = ch_branched.cool.mix( HIC2COOL.out.cool )

    // ---- Module A chain, one task per sample --------------------------------
    EXPECTED( ch_cool, ch_chromsizes )

    PILEUP(
        ch_cool.join( EXPECTED.out.expected ),
        ch_chromsizes,
        ch_fountains_x,
        ch_fountains_a,
    )

    PROFILE( PILEUP.out.pileup )

    /*
     * Fan-in. `hicpup profile` emits tidy long format carrying strain/replicate/
     * view in every row, so merging the per-sample TSVs is a header-preserving
     * concatenation - no join process, and adding a sample changes nothing here.
     */
    ch_merged_profiles = PROFILE.out.profile
        .map { meta, tsv -> tsv }
        .collectFile(name: 'profiles_merged.tsv', keepHeader: true, skip: 1, sort: true,
                     storeDir: "${params.outdir}/profile")

    PLOT_PROFILES( ch_merged_profiles, Channel.value(active_views) )
    PLOT_MATRIX( PILEUP.out.pileup.combine( Channel.fromList(active_views) ) )

    // ---- Provenance ---------------------------------------------------------
    Channel.empty()
        .mix( HIC2COOL.out.versions.first()      )
        .mix( EXPECTED.out.versions.first()      )
        .mix( PILEUP.out.versions.first()        )
        .mix( PROFILE.out.versions.first()       )
        .mix( PLOT_PROFILES.out.versions.first() )
        .collectFile(name: 'software_versions.yml', sort: true,
                     storeDir: "${params.outdir}/pipeline_info")
}
