#!/usr/bin/env python3

__description__ = """
single-cell RNA Isoform analysis pipeline
usage example:
    scRIA -i input-dir -o output-dir mm10
"""

import argparse
import os
import sys
import textwrap
import yaml
import subprocess
### DEFINE FUNCTIONS TO LOAD AND RUN Workflow ###
########################################################

def load_configfile(configfile):
   with open(configfile, "r") as f:
       config = yaml.load(f, Loader=yaml.FullLoader)
   return(config)

def write_configfile(configFile, config):
    with open(configFile, 'w') as f:
        yaml.dump(config, f, default_flow_style=False)

def commonYAMLandLogs(baseDir, args, callingScript):
    """
    Merge dictionaries, write YAML files, construct the snakemake command
    and create the DAG
    """
    #snakemake_path = os.path.dirname(os.path.abspath(callingScript))
    os.makedirs(args.outdir, exist_ok=True)
    if isinstance(args.snakemakeOptions, list):
        args.snakemakeOptions = ' '.join(args.snakemakeOptions)

    # save to configs.yaml in outdir
    config = load_configfile(os.path.join(baseDir, args.config))
    config.update(vars(args))  # This allows modifications of args after handling a user config file to still make it to the YAML given to snakemake!
    write_configfile(os.path.join(args.outdir, 'scRID_config.yaml'), config)

    ## load cluster config
    cluster_config = load_configfile(os.path.join(baseDir, "cluster_config.yaml"))

    snakemake_cmd = """
                    PYTHONNOUSERSITE=True snakemake {snakemakeOptions} --directory {workingdir} --snakefile {snakefile} --jobs {maxJobs} --configfile {configFile} --keep-going --latency-wait 60
                    """.format(snakefile=os.path.join(baseDir, "Snakefile"),
                               maxJobs=args.maxJobs,
                               workingdir=args.outdir,
                               snakemakeOptions=str(args.snakemakeOptions or ''),
                               configFile=os.path.join(args.outdir, 'scRID_config.yaml')).split()

    if args.verbose:
        snakemake_cmd.append("--printshellcmds")

    if args.cluster:
        snakemake_cmd += ["--cluster-config",
                          os.path.join(baseDir, "cluster_config.yaml"),
                          "--cluster", "'" + cluster_config["cluster_cmd"], "'"]
    return " ".join(snakemake_cmd)

def runAndCleanup(args, cmd):
    """
    Actually run snakemake. Kill its child processes on error.
    Also clean up when finished.
    """
    if args.verbose:
        print("\n{}\n".format(cmd))

    # write log file
    f = open(os.path.join(args.outdir, "scRIA.log"), "w")
    f.write(" ".join(sys.argv) + "\n\n")
    f.write(cmd + "\n\n")

    # Run snakemake, stderr -> stdout is needed so readline() doesn't block
    p = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if args.verbose:
        print("PID:", p.pid, "\n")

    while p.poll() is None:
        stdout = p.stdout.readline(1024)
        if stdout:
            sys.stdout.write(stdout.decode('utf-8'))
            f.write(stdout.decode('utf-8'))
            sys.stdout.flush()
            f.flush()
    # This avoids the race condition of p.poll() exiting before we get all the output
    stdout = p.stdout.read()
    if stdout:
        sys.stdout.write(stdout.decode('utf-8'))
        f.write(stdout.decode('utf-8'))
    f.close()

    # Exit with an error if snakemake encountered an error
    if p.returncode != 0:
        sys.stderr.write("Error: snakemake returned an error code of {}, so processing is incomplete!\n".format(p.returncode))
        sys.exit(p.returncode)

### PARSE USER ARGS and RUN ###
########################################################

def parse_args(defaults=None):
    """
    Parse arguments from the command line.
    """
    parser = argparse.ArgumentParser(
        prog=sys.argv[0],
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description=textwrap.dedent(__description__),
        add_help=False
    )

    # Workflow options
    parser.add_argument("-i", "--indir",
                          dest="indir",
                          metavar="STR",
                          help="Input directory with the fastq files",
                          type=str,
                          required=True)

    parser.add_argument("-c", "--config",
                          dest="config",
                          metavar="STR",
                          help="YAML file with workflow configuration",
                          type=str,
                          required=True)

    parser.add_argument("-o", "--outdir",
                          dest="outdir",
                          required=True,
                          help="output directory")

    parser.add_argument("-s", "--snakemakeOptions",
                          dest="snakemakeOptions",
                          metavar="STR",
                          help="Options to pass on to snakemake",
                          type=str,
                          required=False,
                          default=None)

    parser.add_argument("-cl", "--cluster",
                         dest="cluster",
                         action="store_true",
                         default=False,
                         help="run workflow on the cluster (requires configuration of cluster_cmd in the config) (default: '%(default)s')")

    parser.add_argument("-j", "--jobs",
                         dest="maxJobs",
                         metavar="INT",
                         help="maximum number of concurrently submitted cluster jobs (cores if workflow is run locally) (default: '%(default)s')",
                         type=int,
                         default=10)

    parser.add_argument("-h", "--help",
                         action="help",
                         help="show this help message and exit")

    parser.add_argument("--verbose",
                         action="store_true",
                         help="Enable verbose mode")

    return parser


def main():
    #baseDir, workflowDir, defaults = setDefaults(os.path.basename(__file__))
    baseDir = os.path.dirname(__file__)

    # get command line arguments
    parser = parse_args()
    args = parser.parse_args()
    args.outdir = os.path.abspath(args.outdir)
    # Handle YAML and log files
    snakemake_cmd = commonYAMLandLogs(baseDir, args, __file__)
    # Run everything
    runAndCleanup(args, snakemake_cmd)


if __name__ == "__main__":
    main()
