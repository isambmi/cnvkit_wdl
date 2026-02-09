version 1.0
workflow CnvKit {
    input {
        
        Array[File] n_bams
        Array[File] n_bais
        
        String autobin_hdds = "local-disk 10 HDD"
        String docker = "etal/cnvkit:0.9.11"
    }
    
    call AutoBin {
        input:
            docker = docker,
            n_bams = n_bams,
            n_bais = n_bais,
            hdds = autobin_hdds,
    }

    output {
        File target_bed = AutoBin.target_bed
    }
}

task AutoBin {
    input {
        Array[File] n_bams
        Array[File] n_bais
        File intervals
        File access_bed
        File ref_flat
        String docker
        String access_basename = basename(intervals, ".bed")
        String hdds
    }

    command <<<
        set -euo pipefail


        echo "whoami?"
        whoami
        echo "wd:"
        pwd

        su - root
        echo "whoami?"
        whoami
        ls -lha .

        bams=(~{sep=' ' n_bams})
        bais=(~{sep=' ' n_bais})

        local_bams=()
        for i in "${!bams[@]}"; do
            bam="${bams[$i]}"
            bai="${bais[$i]}"
            base="$(basename "$bam")"

            # mv BAM into working dir
            mv "$bam" "./$base"
            mv "$bai" "./$base.bai"              # foo.bam.bai

            echo "checking:"
            ls -l "./$base.bai" 
            ls -l "./$base"
            echo "done checking"

            local_bams+=("./$base")
        done

        echo ${local_bams[@]} > "~{access_basename}.target.bed"
    >>>

    runtime {
        docker: docker
        cpu: 1
        memory: "2 GB"
        disks: hdds
    }

    output {
        File target_bed = "~{access_basename}.target.bed"
    }
}
