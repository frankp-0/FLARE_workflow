version 1.0

import "plot_flare.wdl" as plot

workflow run_flare2 {
  input {
    # Required Inputs
    Array[File] ref_file_list
    Array[File] target_file_list
    Array[String] out_prefix_list
    File genetic_map_file
    File reference_map_file
    Int n_anc

    # Optional Inputs
    Boolean em = true
    Boolean array = false
    Boolean probs = false
    Float min_maf = 0.005
    Int min_mac = 50
    Int gen = 10
    Int seed = -99999
    Int? nthreads
    File? gt_samples
    File? gt_ancestries
    File? excludemarkers

    # Runtime specs
    #Int gb_disk = 20
    Int gb_mem = 10
    Int n_cpu = 1
    Int preemptible = 0
  }

  call create_panel {
    input:
      ref = ref_file_list[0],
      gt  = target_file_list[0],
      out = out_prefix_list[0],
      map = genetic_map_file,
      ref_panel = reference_map_file,
      em = em,
      array = array,
      min_maf = min_maf,
      min_mac = min_mac,
      gen = gen,
      seed = seed,
      nthreads = nthreads,
      gt_samples = gt_samples,
      gt_ancestries = gt_ancestries,
      excludemarkers = excludemarkers,
      gb_mem = gb_mem,
      n_cpu = n_cpu,
      preemptible = preemptible
  }

  call create_model {
    input:
      n_anc = n_anc,
      panel = create_panel.panel,
      out = out_prefix_list[0]
  }

  scatter(i in range(length(ref_file_list))) {
    call flare as flares {
      input:
        ref = ref_file_list[i],
        gt  = target_file_list[i],
        out = out_prefix_list[i],
        map = genetic_map_file,
        ref_panel = reference_map_file,
        em = em,
        array = array,
        probs = probs,
        min_maf = min_maf,
        min_mac = min_mac,
        gen = gen,
        seed = seed,
        nthreads = nthreads,
        model = create_model.model,
        gt_samples = gt_samples,
        gt_ancestries = gt_ancestries,
        excludemarkers = excludemarkers,
        #gb_disk = gb_disk,
        gb_mem = gb_mem,
        n_cpu = n_cpu,
        preemptible = preemptible
    }
  }

  call plot.plot_global_anc {
    input:
      global_anc_array = flares.global_anc
  }

  output {
    Array[File] log_array        = flares.log
    Array[File] model_array      = flares.model
    Array[File] anc_vcf_array    = flares.anc_vcf
    Array[File] global_anc_array = flares.global_anc
    File global_anc_plot = plot_global_anc.global_anc_plot
  }

  meta {
    author: "Frank Ockerman, Brian Chen, Paul Hanson"
    email: "frankpo@unc.edu, brichen@live.unc.edu, PHANSON4@mgh.harvard.edu"
  }
}

task flare {
  input {
    # Required inputs
    String out
    File ref
    File gt
    File map
    File ref_panel

    # Optional Inputs
    Boolean em
    Boolean array
    Boolean probs
    Float min_maf
    Int min_mac
    Int gen
    Int seed
    Int? nthreads
    File? model
    File? gt_samples
    File? gt_ancestries
    File? excludemarkers

    # Runtime specs
    #Int gb_disk
    Int gb_mem
    Int n_cpu
    Int preemptible
  }

  Int gb_disk = ceil(3*(size(ref, "GB") + size(gt, "GB") + size(map, "GB") + size(ref_panel, "GB"))) + 10

  command <<<
    java ~{"-Xmx" + gb_mem + "G"} -jar /flare.jar \
      ~{"out=" + out} \
      ~{"ref=" + ref} \
      ~{"gt=" + gt} \
      ~{"map=" + map} \
      ~{"ref-panel=" + ref_panel} \
      "em=~{em}" \
      "array=~{array}" \
      "probs=~{probs}" \
      "update-p=true" \
      ~{"min-maf=" + min_maf} \
      ~{"min-mac=" + min_mac} \
      ~{"gen=" + gen} \
      ~{"seed=" + seed} \
      ~{"model=" + model} \
      ~{"gt-samples=" + gt_samples} \
      ~{"gt-ancestries=" + gt_ancestries} \
      ~{"excludemarkers=" + excludemarkers} \
      ~{"nthreads=" + nthreads}
  >>>

  output {
    File log        = "${out}.log"
    File model      = "${out}.model"
    File anc_vcf    = "${out}.anc.vcf.gz"
    File global_anc = "${out}.global.anc.gz"
  }

  runtime {
    docker: "frankpo/flare:0.0.1"
    disks: "local-disk ${gb_disk} HDD"
    memory: "${gb_mem} GB"
    cpu: "${n_cpu}"
    preemptible: "${preemptible}"
  }
}

task create_panel {
  input {
    # Required inputs
    String out
    File ref
    File gt
    File map
    File ref_panel

    # Optional Inputs
    Boolean em
    Boolean array
    Float min_maf
    Int min_mac
    Int gen
    Int seed
    Int? nthreads
    File? gt_samples
    File? gt_ancestries
    File? excludemarkers

    # Runtime specs
    #Int gb_disk
    Int gb_mem
    Int n_cpu
    Int preemptible
  }

  Int gb_disk = ceil(3*(size(ref, "GB") + size(gt, "GB") + size(map, "GB") + size(ref_panel, "GB"))) + 10

  command <<<
    java ~{"-Xmx" + gb_mem + "G"} -jar /flare.jar \
      ~{"out=" + out} \
      ~{"ref=" + ref} \
      ~{"gt=" + gt} \
      ~{"map=" + map} \
      ~{"ref-panel=" + ref_panel} \
      "em=~{em}" \
      "array=~{array}" \
      panel-probs=true \
      ~{"min-maf=" + min_maf} \
      ~{"min-mac=" + min_mac} \
      ~{"gen=" + gen} \
      ~{"seed=" + seed} \
      ~{"gt-samples=" + gt_samples} \
      ~{"gt-ancestries=" + gt_ancestries} \
      ~{"excludemarkers=" + excludemarkers} \
      ~{"nthreads=" + nthreads}
  >>>

  output {
    File panel = "${out}.panels"
  }

  runtime {
    docker: "frankpo/flare:0.0.1"
    disks: "local-disk ${gb_disk} HDD"
    memory: "${gb_mem} GB"
    cpu: "${n_cpu}"
    preemptible: "${preemptible}"
  }
}

task create_model {
  input {
    Int n_anc
    File panel
    String out
  }

  command <<<
    python3 /usr/local/bin/create_model_file.py ~{n_anc} ~{panel} ~{out}
  >>>

  output {
    File model = "${out}.model"
  }

  runtime {
    docker: "frankpo/flare:0.0.1"
  }
}
