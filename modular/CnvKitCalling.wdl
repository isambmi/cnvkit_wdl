version 1.0
workflow CnvKitCalling {
    input {
        File target_coverage
        File antitarget_coverage
        File reference
        Int segment_cpu = 1 
        String docker = "getwilds/cnvkit:0.9.10"
        String? output_name
        
    }
    
    call Fix {
        input:
            docker = docker,
            output_basename = select_first([output_name, basename(target_coverage, ".targetcoverage.cnn")]),
            target_coverage = target_coverage,
            antitarget_coverage = antitarget_coverage,
            reference = reference

    }

    call Segment {
        input:
            cnr = Fix.cnr,
            n_proc = segment_cpu,
            output_basename = basename(Fix.cnr, ".cnr"),
            docker = docker
    }

    output {
        File cnr = Fix.cnr
        File cns = Segment.cns
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
        cpu: 1
        memory: "4 GB"
        disks: "local-disk 2 HDD"        
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
        cpu: n_proc
        memory: "4 GB"
        disks: "local-disk 2 HDD"
    }

    output {
        File cns = "~{output_basename}.cns"
    }
}
