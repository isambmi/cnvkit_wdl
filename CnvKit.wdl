version 1.0
workflow CnvKit {
    input {
        
        File fasta_gz
        Array[File] n_bams
        Array[File?] n_bais
        File ref_flat
        File intervals
        Array[File] t_bams
        Array[File?] t_bais
        
        Int n_proc = 8 # number of subprocesses to run under `coverage` and `segment`
        String docker = "etal/cnvkit:0.9.11"
        String project_name = "project" # will be used to name reference and aggregated segment files
        
    }

    call UnpackFasta {
        input:
         fasta_gz = fasta_gz
    }

    call Access {
        input:
            docker = docker,
            fasta = UnpackFasta.fasta
    }
    
    call AutoBin {
        input:
            docker = docker,
            n_bams = n_bams,
            n_bais = n_bais,
            ref_flat = ref_flat,
            intervals = intervals,
            access_bed = Access.access_bed
    }

    scatter(i in range(length(n_bams))) {

        call Coverage as NormalCoverage {
            input:
                docker = docker,
                n_proc = n_proc,
                bam = n_bams[i],
                bai = n_bais[i],
                output_basename = basename(basename(n_bams[i], ".bam"), ".cram"),
                target_bed = AutoBin.target_bed,
                antitarget_bed = AutoBin.antitarget_bed
        }
        
    }
    
    # tumor workflow
    scatter(i in range(length(t_bams))) {

        call Coverage as TumorCoverage {
            input:
                docker = docker,
                n_proc = n_proc,
                bam = t_bams[i],
                bai = t_bais[i],
                output_basename = basename(basename(t_bams[i], ".bam"), ".cram"),
                target_bed = AutoBin.target_bed,
                antitarget_bed = AutoBin.antitarget_bed

        }
        
        call Fix {
            input:
                docker = docker,
                output_basename = basename(TumorCoverage.target_coverage, ".targetcoverage.cnn"),
                target_coverage = TumorCoverage.target_coverage,
                antitarget_coverage = TumorCoverage.antitarget_coverage,
                reference = Reference.reference

        }

        call Segment {
            input:
                cnr = Fix.cnr,
                n_proc = n_proc,
                output_basename = basename(Fix.cnr, ".cnr"),
                docker = docker
        }

    }

    call Reference {
        input:
            docker = docker,
            targetcoverages = NormalCoverage.target_coverage,
            antitargetcoverages = NormalCoverage.antitarget_coverage,
            fasta = UnpackFasta.fasta,
            project_name = project_name
    }

    call AggregateSegments {
        input:
            docker = docker,
            segments = Segment.cns,
            project_name = project_name
    }


    output {
        File reference = Reference.reference
        # Array[File] cnr = Fix.cnr
        Array[File] cns = Segment.cns
        File aggregated_segments = AggregateSegments.aggregated_segments
    }
}

task UnpackFasta{
    input {
        File fasta_gz
    }

    command <<<
        tar -xzvf ~{fasta_gz}
    >>>

    output {
        File fasta = '~{basename(fasta_gz, ".tar.gz")}'
    }
}

task Access {
    input {
        File fasta
        String docker
    }

    command <<<
        cnvkit.py access ~{fasta} -o ~{basename(basename(docker, ".fa"), ".fasta")}.bed
    >>>

    runtime {
        docker: docker
    }

    output {
        File access_bed = '~{basename(basename(docker, ".fa"), ".fasta")}.bed'
    }
}

task AutoBin {
    input {
        Array[File] n_bams
        Array[File?] n_bais
        File intervals
        File access_bed
        File ref_flat
        String docker
        String access_basename = basename(intervals, ".bed")
    }

    command <<<
        cnvkit.py autobin \
            ~{sep=" " n_bams} \
            -t ~{intervals} \
            -g ~{access_bed} \
            --annotate ~{ref_flat} \
            --short-names
    >>>

    runtime {
        docker: docker
    }

    output {
        File target_bed = "~{access_basename}.target.bed"
        File antitarget_bed = "~{access_basename}.antitarget.bed"
    }
}

task Coverage {
    input {
        File bam
        File? bai
        String output_basename
        File target_bed
        File antitarget_bed
        
        Int n_proc
        String docker
    }

    command <<<
        cnvkit.py coverage \
            ~{bam} \
            ~{target_bed} \
            -p ~{n_proc} \
            -o ~{output_basename}.targetcoverage.cnn
        
        cnvkit.py coverage \
            ~{bam} \
            ~{antitarget_bed} \
            -p ~{n_proc} \
            -o ~{output_basename}.antitargetcoverage.cnn
    >>>

    runtime {
        docker: docker
    }

    output {
        File target_coverage = "~{output_basename}.targetcoverage.cnn"
        File antitarget_coverage = "~{output_basename}.antitargetcoverage.cnn"
    }
}

task Fix {
    input {
        File target_coverage
        File antitarget_coverage
        File reference
        String output_basename
        String docker
    }

    command <<<
        cnvkit.py fix \
            ~{target_coverage} ~{antitarget_coverage} \
            ~{reference} \
            -o ~{output_basename}.cnr
    >>>

    runtime {
        docker: docker
    }

    output {
        File cnr = "~{output_basename}.cnr"
    }
}

task Segment {
    input {
        File cnr
        Int n_proc
        String output_basename
        String docker
    }

    command <<<
        cnvkit.py segment \
            ~{cnr} \
            -p ~{n_proc} \
            -o ~{output_basename}.cns
    >>>

    runtime {
        docker: docker
    }

    output {
        File cns = "~{output_basename}.cns"
    }
}

task Reference {
    input {
        Array[File] targetcoverages
        Array[File] antitargetcoverages
        File fasta
        String docker
        String project_name
    }

    command <<<
        cnvkit.py reference \
            -t ~{sep=" -t " targetcoverages} \
            -a ~{sep=" -a " antitargetcoverages} \
            --fasta ~{fasta} \
            -o ~{project_name}_reference.cnn
    >>>

    runtime {
        docker: docker
    }

    output {
        File reference = "~{project_name}_reference.cnn"
    }
}

task AggregateSegments {
    input {
        String docker
        Array[File] segments
        String project_name
    }

    command <<<
        cnvkit.py export seg \
            ~{sep=' ' segments} \
            -o ~{project_name}.seg.txt
    >>>

    runtime {
        docker: docker
    }

    output {
        File aggregated_segments = "~{project_name}.seg.txt"
    }
}
