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
        String docker
        String hdds
    }

    command <<<
        # set -euo pipefail


        echo "whoami?"
        whoami
        echo "wd:"
        pwd

        # su - root
        # echo "whoami?"
        # whoami
        ls -lha .
        ls -lha dg.4DFC_3d449417-de6d-42cc-bdee-42c6f225210a
        ls -lha dg.4DFC_02104e71-544d-492b-b864-d51cb6664159

        bams=(~{sep=' ' n_bams})
        bais=(~{sep=' ' n_bais})

        local_bams=()
        for i in "${!bams[@]}"; do
            bam="${bams[$i]}"
            bai="${bais[$i]}"
            base="$(basename "$bam")"

            echo "bam and bai before:"
            echo $bam
            ls -l $bam
            echo $bai
            ls -l $bai
            bam="${bam/\/mnt\/disks\/cromwell_root/\/.}"
            bai="${bai/\/mnt\/disks\/cromwell_root/\/.}"
            echo "bam and bai after:"
            echo $bam
            ls -l $bam
            echo $bai
            ls -l $bai
            
            # ln BAM into working dir
            ln "$bam" "./$base"
            ln "$bai" "./$base.bai"              # foo.bam.bai

            echo "checking:"
            ls -l "./$base.bai" 
            ls -l "./$base"
            echo "done checking"

            local_bams+=("./$base")
        done

        echo ${local_bams[@]} > this.target.bed
    >>>

    runtime {
        docker: docker
        cpu: 1
        memory: "2 GB"
        disks: hdds
    }

    output {
        File target_bed = "this.target.bed"
    }
}
