version 1.0
workflow CnvKit {
    input {
        
        File bam
        File bai
        File target_bed
        File antitarget_bed
        
        Int coverage_cpu = 1 
        String docker = "getwilds/cnvkit:0.9.10"
        
    }

    call Coverage {
        input:
            docker = docker,
            n_proc = coverage_cpu,
            bam = bam,
            bai = bai,
            output_basename = basename(bam, ".bam"),
            target_bed = target_bed,
            antitarget_bed = antitarget_bed
    }
    
    output {
        File target_coverage = Coverage.target_coverage
        File antitarget_coverage = Coverage.target_coverage
    }
}

task Coverage {
    input {
        File bam
        File bai
        String output_basename
        File target_bed
        File antitarget_bed
        
        Int n_proc
        String docker
        Int? disk_gb_override
        Float disk_multiplier = 1.3
        Int disk_padding_gb = 20
    }

    Int bam_gb = ceil(size(bam, "GiB"))
    Int disk_gb = select_first([disk_gb_override, ceil(bam_gb * disk_multiplier + disk_padding_gb)])


    command <<<

        ln "~{bam}" "./~{output_basename}.bam"
        ln "~{bai}" "./~{output_basename}.bam.bai"
        
        touch "./~{output_basename}.bam.bai"

        cnvkit.py coverage \
            ~{output_basename}.bam \
            ~{target_bed} \
            -p ~{n_proc} \
            -o ~{output_basename}.targetcoverage.cnn
        
        cnvkit.py coverage \
            ~{output_basename}.bam \
            ~{antitarget_bed} \
            -p ~{n_proc} \
            -o ~{output_basename}.antitargetcoverage.cnn
    >>>

    runtime {
        docker: docker
        cpu: n_proc
        memory: "5 GB"
        disks: "local-disk " + disk_gb + " HDD"
    }

    output {
        File target_coverage = "~{output_basename}.targetcoverage.cnn"
        File antitarget_coverage = "~{output_basename}.antitargetcoverage.cnn"
    }
}
