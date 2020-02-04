#!/usr/bin/env nextflow

nextflow.preview.dsl=2

params.fasta = 'nt.fa'
params.taxonomy_nodes = 'taxonomy/nodes.dmp'
params.taxonomy_names = 'taxonomy/names.dmp'
params.acc2taxid = 'acc2taxid.map'

params.outdir = 'results'

params.cpus = 32
params.memory = '256 GB'
params.name = null

//=============================================================================
// WORKFLOW RUN PARAMETERS LOGGING
//=============================================================================

// Has the run name been specified by the user?
//  this has the bonus effect of catching both -name and --name
custom_runName = params.name
if( !(workflow.runName ==~ /[a-z]+_[a-z]+/) ){
  custom_runName = workflow.runName
}

if (params.executor == 'slurm' && params.queue == "") {
  exit 1, "You must specify a valid Slurm queue (e.g. '--queue <queue name>' (see `\$ sinfo` output for available queues)) to run this workflow with the 'slurm' executor!"
}


// Header log info
log.info """=======================================================
Centrifuge Build DB
======================================================="""
def summary = [:]
summary['Run Name']         = custom_runName ?: workflow.runName
summary['Input Fasta'] = file(params.fasta)
summary['Taxonomy nodes.dmp'] = file(params.taxonomy_nodes)
summary['Taxonomy names.dmp'] = file(params.taxonomy_names)
summary['Accessions to Taxids mappings'] = file(params.acc2taxid)
summary['CPUs'] = params.cpus
summary['Memory'] = params.memory
summary['Container Engine'] = workflow.containerEngine
if(workflow.containerEngine) summary['Container'] = workflow.container
summary['Current home']   = "$HOME"
summary['Current user']   = "$USER"
summary['Current path']   = "$PWD"
summary['Working dir']    = workflow.workDir
summary['Output dir']     = file(params.outdir)
summary['Script dir']     = workflow.projectDir
summary['Config Profile'] = workflow.profile
if(workflow.profile == 'slurm') summary['Slurm Queue'] = params.slurm_queue
log.info summary.collect { k,v -> "${k.padRight(15)}: $v" }.join("\n")
log.info "========================================="

process CENTRIFUGE_BUILD {
  publishDir "${params.outdir}/${fasta_name}", pattern: "*.cf", mode: 'move'
  cpus params.cpus
  memory params.memory
  echo true

  input:
    path(fasta)
    path(acc2taxid)
    path(taxonomy_names)
    path(taxonomy_nodes)
  output:
    path('*.cf')

  script:
  fasta_name = file(fasta).getSimpleName()
  """
  centrifuge-build \\
    -p ${task.cpus} \\
    --conversion-table $acc2taxid \\
    --taxonomy-tree $taxonomy_nodes \\
    --name-table $taxonomy_names \\
    $fasta $fasta_name
  """
}

workflow {
  ch_fasta = Channel.fromPath(params.fasta)
  ch_acc2taxid = Channel.value(file(params.acc2taxid))
  ch_taxonomy_nodes = Channel.value(file(params.taxonomy_nodes))
  ch_taxonomy_names = Channel.value(file(params.taxonomy_names))

  CENTRIFUGE_BUILD(ch_fasta, ch_acc2taxid, ch_taxonomy_names, ch_taxonomy_nodes)
}

