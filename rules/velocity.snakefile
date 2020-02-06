### velocit indexing (prepare files)

rule velocity_index:
    input:
        "annotations/cDNA_introns.fa"
    output:
        "annotations/cDNA_introns.idx"
    log:
        out = "logs/velocity_index.out",
        err = "logs/velocity_index.err"
    threads: 1
    conda: CONDA_SHARED_ENV
    shell: "kallisto index -i {output} -k 31 {input} > {log.out} 2> {log.err}"

### Velocity mapping (to combined cDNA-intron index)
rule velocity_map:
    input:
        R1 = "FASTQ_trimmed/{sample}"+reads[0]+".fastq.gz" if trim else "FASTQ/{sample}"+reads[0]+".fastq.gz",
        R2 = "FASTQ_trimmed/{sample}"+reads[1]+".fastq.gz" if trim else "FASTQ/{sample}"+reads[1]+".fastq.gz",
        idx = "annotations/cDNA_introns.idx"
    output:
        bus = "velocity_quant/{sample}/output.bus",
        matrix = "velocity_quant/{sample}/matrix.ec",
        transcripts = "velocity_quant/{sample}/transcripts.txt"
    params:
        outdir = "velocity_quant/{sample}",
        protocol = lambda wildcards: "0,6,14:0,0,6:1,0,0" if protocol == 'VASASeq' else protocol
    log:
        out = "logs/velocity_map.{sample}.out",
        err = "logs/velocity_map.{sample}.err"
    threads: 20
    conda: CONDA_SHARED_ENV
    shell:
        "kallisto bus -i {input.idx} -x {params.protocol} -t {threads} -o {params.outdir} {input.R1} {input.R2} > {log.out} 2> {log.err}"

rule velocyto_correct_sort:
    input:
        whitelist = "whitelist_barcodes.txt",
        busfile = "velocity_quant/{sample}/output.bus"
    output:
        "velocity_quant/{sample}/output.correct.sort.bus"
    params:
        outdir = 'velocity_quant/{sample}'
    log: "logs/correct_sort_velocyto_{sample}.out"
    threads: 10
    conda: CONDA_SHARED_ENV
    shell:
        """
        mkdir -p {params.outdir};
        bustools correct -w "{input.whitelist}" \
        -o {params.outdir}/output.correct.bus {input.busfile} > {log} 2>&1;
        bustools sort -t {threads} -o {output} {params.outdir}/output.correct.bus >> {log};
        rm {params.outdir}/output.correct.bus
        """
## bustools v 0.39.3
## for spliced counts, we subset the bus file to get the complement of the "introns" transcript set
rule spliced_capture:
    input:
        mtx = "velocity_quant/{sample}/matrix.ec",
        introns = "annotations/introns_tx_to_capture.txt",
        busfile = "velocity_quant/{sample}/output.correct.sort.bus",
        transcripts = "velocity_quant/{sample}/transcripts.txt"
    output: "velocity_quant/{sample}/spliced.bus"
    log: "logs/spliced_capture_{sample}.out"
    threads: 1
    conda: CONDA_SHARED_ENV
    shell:
        "bustools capture -s -x -o {output} -c {input.introns} \
        -e {input.mtx} -t {input.transcripts} {input.busfile} > {log} 2>&1"

## for unspliced counts, we subset the bus file to get the complement of the captured set from "cDNA" list
rule unspliced_capture:
    input:
        mtx = "velocity_quant/{sample}/matrix.ec",
        cdna = "annotations/cDNA_tx_to_capture.txt",
        busfile = "velocity_quant/{sample}/output.correct.sort.bus",
        transcripts = "velocity_quant/{sample}/transcripts.txt"
    output: "velocity_quant/{sample}/unspliced.bus"
    log: "logs/unspliced_capture_{sample}.out"
    threads: 1
    conda: CONDA_SHARED_ENV
    shell:
        "bustools capture -s -x -o {output} -c {input.cdna} \
        -e {input.mtx} -t {input.transcripts} {input.busfile} > {log} 2>&1"

## instead of counting using bustools. I count using the text files myself
rule txt_spliced:
    input:
        "velocity_quant/{sample}/spliced.bus"
    output:
        "velocity_quant/{sample}/spliced.txt"
    log: "logs/txt_spliced.{sample}.out"
    threads: 1
    conda: CONDA_SHARED_ENV
    shell: "bustools text -o {output} {input} > {log}"

rule txt_unspliced:
    input:
        "velocity_quant/{sample}/unspliced.bus"
    output:
        "velocity_quant/{sample}/unspliced.txt"
    log: "logs/txt_spliced.{sample}.out"
    threads: 1
    conda: CONDA_SHARED_ENV
    shell: "bustools text -o {output} {input} > {log}"

rule tcc_spliced:
    input:
        tr2g = "annotations/tr2g.tsv",
        ecToTr = "velocity_quant/{sample}/matrix.ec",
        transcripts = "annotations/cDNA_tx_to_capture.txt",
        busfile = "velocity_quant/{sample}/spliced.txt"
    output:
         mtx = "velocity_quant/{sample}/TCC_spliced/output.mtx",
         ec = "velocity_quant/{sample}/TCC_spliced/output.ec.txt",
         bc = "velocity_quant/{sample}/TCC_spliced/output.barcodes.txt",
         ecToGene = "velocity_quant/{sample}/TCC_spliced/ec-to-gene.txt"
    params:
        out = "velocity_quant/{sample}/TCC_spliced/",
        rscript = os.path.join(workflow.basedir, "tools", "get_ec_geneMap.R")
    log: "logs/tcc_spliced_{sample}.out"
    threads: 1
    conda: CONDA_SHARED_ENV
    shell:
        "Rscript {params.rscript} {input.tr2g} {input.busfile} {input.transcripts} {input.ecToTr} {params.out} 2> {log} 2>&1"

rule tcc_unspliced:
    input:
        tr2g = "annotations/tr2g.tsv",
        ecToTr = "velocity_quant/{sample}/matrix.ec",
        transcripts = "annotations/introns_tx_to_capture.txt",
        busfile = "velocity_quant/{sample}/unspliced.txt"
    output:
         mtx = "velocity_quant/{sample}/TCC_unspliced/output.mtx",
         ec = "velocity_quant/{sample}/TCC_unspliced/output.ec.txt",
         bc = "velocity_quant/{sample}/TCC_unspliced/output.barcodes.txt",
         ecToGene = "velocity_quant/{sample}/TCC_unspliced/ec-to-gene.txt"
    params:
        out = "velocity_quant/{sample}/TCC_unspliced/",
        rscript = os.path.join(workflow.basedir, "tools", "get_ec_geneMap.R")
    log: "logs/tcc_unspliced_{sample}.out"
    threads: 1
    conda: CONDA_SHARED_ENV
    shell:
        "Rscript {params.rscript} {input.tr2g} {input.busfile} {input.transcripts} {input.ecToTr} {params.out} 2> {log} 2>&1"

rule geneCounts_spliced:
    input:
        ecToGene = "velocity_quant/{sample}/TCC_spliced/ec-to-gene.txt",
        mtx = "velocity_quant/{sample}/TCC_spliced/output.mtx",
        ec = "velocity_quant/{sample}/TCC_spliced/output.ec.txt",
        bc = "velocity_quant/{sample}/TCC_spliced/output.barcodes.txt"
    output:
         mtx = "velocity_quant/{sample}/geneCounts_spliced/output.mtx",
         bc = "velocity_quant/{sample}/geneCounts_spliced/output.barcodes.txt",
         genes = "velocity_quant/{sample}/geneCounts_spliced/output.genes.txt"
    params:
        out = "transcripts_quant/{sample}/geneCounts_spliced/",
        rscript = os.path.join(workflow.basedir, "tools", "get_geneCounts.R")
    log: "logs/get_geneCounts.{sample}.out"
    threads: 1
    conda: CONDA_SHARED_ENV
    shell:  #"{params.bustools} count --genecounts -o {params.out} -g {input.t2g} -e {input.mtx} -t {input.transcripts} {input.busfile} > {log} 2>&1"
        "Rscript {params.rscript} {input.ecToGene} {input.mtx} {input.ec} {input.bc} {params.out} > {log} 2>&1"

rule geneCounts_unspliced:
    input:
        ecToGene = "velocity_quant/{sample}/TCC_unspliced/ec-to-gene.txt",
        mtx = "velocity_quant/{sample}/TCC_unspliced/output.mtx",
        ec = "velocity_quant/{sample}/TCC_unspliced/output.ec.txt",
        bc = "velocity_quant/{sample}/TCC_unspliced/output.barcodes.txt"
    output:
         mtx = "velocity_quant/{sample}/geneCounts_unspliced/output.mtx",
         bc = "velocity_quant/{sample}/geneCounts_unspliced/output.barcodes.txt",
         genes = "velocity_quant/{sample}/geneCounts_unspliced/output.genes.txt"
    params:
        out = "transcripts_quant/{sample}/geneCounts_unspliced/",
        rscript = os.path.join(workflow.basedir, "tools", "get_geneCounts.R")
    log: "logs/get_geneCounts.{sample}.out"
    threads: 1
    conda: CONDA_SHARED_ENV
    shell:  #"{params.bustools} count --genecounts -o {params.out} -g {input.t2g} -e {input.mtx} -t {input.transcripts} {input.busfile} > {log} 2>&1"
        "Rscript {params.rscript} {input.ecToGene} {input.mtx} {input.ec} {input.bc} {params.out} > {log} 2>&1"

rule velocyto:
    input:
        unspliced = expand("velocity_quant/{sample}/geneCounts_unspliced/output.mtx", sample = samples),
        spliced = expand("velocity_quant/{sample}/geneCounts_spliced/output.mtx", sample = samples),
        t2g = "annotations/tr2g.tsv"
    output:
        adata_all = "velocity_output/anndata.loom",
        adata_filt = "velocity_output/anndata_filtered.loom",
        qc_metrics = "velocity_output/qc-metrics.csv",
        velo_fig1 = "velocity_output/velocity-grid_louvain.png",
        velo_fig2 = "velocity_output/velocity-grid_samples.png"
    params:
        scvelo = os.path.join(workflow.basedir, "tools", "scVelo_wrapper.py"),
        samples = " ".join(samples),
        outdir = "velocity_output"
    log: "logs/velocity_report.out"
    threads: 2
    conda: CONDA_SHARED_ENV
    shell:
        "{params.scvelo} -s {params.samples} -o {params.outdir} -t {input.t2g} > {log} 2>&1"
