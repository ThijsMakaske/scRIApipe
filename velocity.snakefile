
rule cDNA_capture:
    input:
        mtx = "velocity_quant/{sample}/matrix.ec",
        cdna = "annotations/cDNA_tx_to_capture.txt",
        busfile = "velocity_quant/{sample}/output.correct.sort.bus",
        transcripts = "velocity_quant/{sample}/transcripts.txt"
    output:
        ec = "velocity_quant/{sample}/cDNA_capture/split.ec",
        bus = "velocity_quant/{sample}/cDNA_capture/split.bus"
    params:
        out = "velocity_quant/{sample}/cDNA_capture"
    log:
        out = "logs/cDNA_capture.out",
        err = "logs/cDNA_capture.err"
    threads: 2
    conda: CONDA_scRIA_ENV
    shell:
    "bustools capture -s -o {params.out} -c {input.cdna} \
    -e {input.mtx} -t {input.transcripts} {input.busfile} > {log.out} 2> {log.err}"

rule introns_capture:
    input:
        mtx = "velocity_quant/{sample}/matrix.ec",
        introns = "annotations/introns_tx_to_capture.txt",
        busfile = "velocity_quant/{sample}/output.correct.sort.bus",
        transcripts = "velocity_quant/{sample}/transcripts.txt"
    output:
        ec = "velocity_quant/{sample}/introns_capture/split.ec",
        bus = "velocity_quant/{sample}/introns_capture/split.bus"
    params:
        out = "velocity_quant/{sample}/introns_capture"
    log:
        out = "logs/introns_capture.out",
        err = "logs/introns_capture.err"
    threads: 2
    conda: CONDA_scRIA_ENV
    shell:
    "bustools capture -s -o {params.out} -c {input.introns} \
    -e {input.mtx} -t {input.transcripts} {input.busfile} > {log.out} 2> {log.err}"

rule spliced_counts:
    input:
        t2g = "annotations/tr2g.tsv",
        mtx = "velocity_quant/{sample}/matrix.ec",
        bus = "velocity_quant/{sample}/cDNA_capture/split.bus",
        transcripts = "velocity_quant/{sample}/transcripts.txt"
    output:
    params:
        prefix = "velocity_quant/{sample}/spliced_counts/s"
    log:
        out = "logs/spliced_counts.out",
        err = "logs/spliced_counts.err"
    threads: 2
    conda: CONDA_scRIA_ENV
    shell:  "bustools count -o {params.prefix} -g {input.t2g} -e {input.mtx} \
    -t {input.transcripts} --genecounts {input.bus} > {log.out} 2> {log.err}"

rule unspliced_counts:
    input:
        t2g = "annotations/tr2g.tsv",
        mtx = "velocity_quant/{sample}/matrix.ec",
        bus = "velocity_quant/{sample}/introns_capture/split.bus",
        transcripts = "velocity_quant/{sample}/transcripts.txt"
    output:
    params:
        prefix = "velocity_quant/{sample}/unspliced_counts/u"
    log:
        out = "logs/unspliced_counts.out",
        err = "logs/unspliced_counts.err"
    threads: 2
    conda: CONDA_scRIA_ENV
    shell:  "bustools count -o {params.prefix} -g {input.t2g} -e {input.mtx} \
    -t {input.transcripts} --genecounts {input.bus} > {log.out} 2> {log.err}"
