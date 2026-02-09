version 1.0
workflow CnvKit {
    input {
        
        Array[File] n_bams
        Array[File] n_bais
        File ref_flat
        File intervals
        File access_bed = "gs://fc-c65c86f4-557a-4693-abd8-9010a881c746/cnvkit:0.9.11.bed"
        
        String autobin_hdds = "local-disk 100 HDD"
        String docker = "etal/cnvkit:0.9.11"
        String project_name = "project" # will be used to name reference and aggregated segment files
        
    }
    
    call AutoBin {
        input:
            docker = docker,
            n_bams = n_bams,
            n_bais = n_bais,
            hdds = autobin_hdds,
            ref_flat = ref_flat,
            intervals = intervals,
            access_bed = access_bed
    }

    output {
        File target_bed = AutoBin.target_bed
        File antitarget_bed = AutoBin.antitarget_bed
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

        bams=(~{sep=' ' n_bams})
        bais=(~{sep=' ' n_bais})

        if [ "${#bams[@]}" -ne "${#bais[@]}" ]; then
            echo "ERROR: n_bams and n_bais lengths differ: ${#bams[@]} vs ${#bais[@]}" >&2
            exit 1
        fi

        local_bams=()
        for i in "${!bams[@]}"; do
            echo $i
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

        cnvkit.py autobin \
            ${local_bams[@]}  \
            -t ~{intervals} \
            -g ~{access_bed} \
            --annotate ~{ref_flat} \
            --short-names
    >>>

    runtime {
        docker: docker
        cpu: 1
        memory: "16 GB"
        disks: hdds
    }

    output {
        File target_bed = "~{access_basename}.target.bed"
        File antitarget_bed = "~{access_basename}.antitarget.bed"
    }
}
