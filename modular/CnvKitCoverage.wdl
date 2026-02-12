version 1.0
workflow CnvKit {
    input {
        
        File bam
        File bai
        File target_bed
        File antitarget_bed
        File sample_id = basename(bam, ".bam")
        
        Int coverage_cpu = 1 
        String docker = "getwilds/cnvkit:0.9.10"
        
    }

    call Coverage {
        input:
            docker = docker,
            n_proc = coverage_cpu,
            bam = bam,
            bai = bai,
            sample_id = sample_id,
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
        String sample_id
        File target_bed
        File antitarget_bed
        
        Int n_proc
        String docker
        Int? disk_gb_override
        Float disk_multiplier = 1.25
        Int disk_padding_gb = 5
    }

    Int bam_gb = ceil(size(bam, "GiB"))
    Int disk_gb = select_first([disk_gb_override, ceil(bam_gb * disk_multiplier + disk_padding_gb)])


    command <<<

        ln "~{bam}" "./~{sample_id}.bam"
        ln "~{bai}" "./~{sample_id}.bam.bai"
        
        touch "./~{sample_id}.bam.bai"

        cnvkit.py coverage \
            ~{sample_id}.bam \
            ~{target_bed} \
            -p ~{n_proc} \
            -o ~{sample_id}.targetcoverage.cnn
        
        cnvkit.py coverage \
            ~{sample_id}.bam \
            ~{antitarget_bed} \
            -p ~{n_proc} \
            -o ~{sample_id}.antitargetcoverage.cnn
    >>>

    runtime {
        docker: docker
        cpu: n_proc
        memory: "2 GB"
        disks: "local-disk " + disk_gb + " HDD"
    }

    output {
        File target_coverage = "~{sample_id}.targetcoverage.cnn"
        File antitarget_coverage = "~{sample_id}.antitargetcoverage.cnn"
    }
}
